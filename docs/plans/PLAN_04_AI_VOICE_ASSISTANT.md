# PLAN 04 – Trợ lý AI cho FOORA

> Mục tiêu: chat tiếng Việt dựa trên tồn kho household, nhập câu hỏi bằng giọng nói, gợi ý món ưu tiên nguyên liệu sắp hết hạn, và **đề xuất** cập nhật kho để người dùng duyệt. Đây là kế hoạch triển khai; các con số quota và model là cấu hình ban đầu, cần kiểm tra lại trên môi trường chạy trước khi phát hành.

## 1. Hiện trạng và phạm vi

- Flutter đã có khung `lib/features/ai/` nhưng phần lớn là stub. `functions/src/ai/index.ts` chưa export callable.
- Inventory, household mặc định, membership, receipt scan và payment đã có luồng riêng; AI phải dùng lại repository, constants và quy tắc hiện có.
- `speech_to_text` đã có trong `pubspec.yaml`; cần kiểm tra quyền và khả năng nhận tiếng Việt trên thiết bị thật.
- Shopping list thuộc PLAN 01 và chưa hiện diện trong code đang chạy. Chat, recipe và cập nhật inventory **không phụ thuộc** PLAN 01. Chỉ nút “thêm nguyên liệu thiếu vào danh sách mua” triển khai sau khi API shopping list hoàn thành.

### Phạm vi bản đầu

1. **Một màn chat AI có cả hai cách nhập ngay từ bản đầu:** gõ text hoặc bấm mic nói tiếng Việt. Speech-to-text đưa bản chép lời vào cùng ô chat để người dùng sửa; nút Gửi dùng chung luồng `aiAssistant`. Hỗ trợ hỏi tồn kho, số lượng, hạn dùng và món nên dùng trước bằng cả hai cách.
2. Gợi ý tối đa ba món dựa trên inventory active; chỉ ra nguyên liệu có và thiếu.
3. Đề xuất `consume`, `discard`, `set_quantity`, `add_inventory` từ tin nhắn gõ hoặc nói; chỉ cập nhật khi người dùng xác nhận.
4. Quota theo ngày cho lời gọi AI; lịch sử chat cá nhân. Chuyển giọng nói thành text chưa tốn quota, chỉ bấm Gửi mới tính lượt.

Voice luôn nghe, tự gửi lời nói, tự ghi kho, tư vấn y tế và thao tác shopping list nằm ngoài bản đầu.

## 2. Quy tắc dữ liệu cần thống nhất trước khi viết action

### 2.1 Số lượng và FEFO

- `inventory_items.quantity` là **số lượng còn hiện tại**, không phải số lượng mua ban đầu.
- Thêm `initialQuantity` là mốc để tính `remainingPercentage = round(quantity / initialQuantity * 100)`, giới hạn trong 0..100. Khi thêm item mới, đặt `initialQuantity = quantity`.
- Với item cũ thiếu `initialQuantity`: migration/backfill **trước phase cập nhật kho**; nếu `remainingPercentage > 0`, ước lượng `quantity / (remainingPercentage / 100)` và đánh dấu giá trị migration. Nếu không thể suy ra đáng tin cậy, dùng `quantity` làm mốc mới và ghi nhận việc reset phần trăm. Kiểm thử lại màn sửa item, status và mọi chỗ đọc `remainingPercentage`; cập nhật `DATABASE.md` và `firestore.rules`.
- Một `inventory_item` là một batch. Khi dùng nhiều batch cùng tên, backend chia lượng trừ theo `expirationDate` tăng dần (FEFO), rồi `createdAt`/ID để có thứ tự ổn định. Nếu câu nói hoặc đơn vị mơ hồ, yêu cầu người dùng chọn batch và lượng; không đoán.
- `set_quantity` đặt lượng còn lại cho **một batch được chọn rõ**. Nếu lời nói chỉ có tên và trùng nhiều batch, yêu cầu chọn batch. Không cho tăng số lượng qua `set_quantity`; mua thêm tạo batch mới qua `add_inventory`.
- Không tự đổi `kg/g`, `hộp/quả` hoặc cắt lượng yêu cầu theo lượng tồn. Khi thiếu lượng, vượt tồn, đơn vị không khớp hay confidence thấp: `needsReview`; user phải sửa hoặc bỏ action.

### 2.2 Recipe

- Chỉ item `active` và chưa quá hạn mới được đưa vào danh sách nguyên liệu có thể dùng; món quá hạn chỉ được nêu như cảnh báo.
- Recipe tối đa ba món, mỗi món tối đa 12 bước; ưu tiên item sắp hết hạn. `usesRefs` phải tham chiếu item trong context; nguyên liệu thiếu được hiển thị, chưa tạo shopping item.
- Recipe là gợi ý, không tự trừ kho. Nếu sau này thêm nút “Đã nấu món này”, nút đó đi qua cùng luồng đề xuất và xác nhận action.

## 3. Kiến trúc và hợp đồng API

```text
Flutter chat / voice transcript
  -> aiAssistant callable: auth, household, quota, context, Gemini, validator
  -> reply + recipe + action proposals (Firestore: client chỉ đọc)
  -> người dùng sửa/chọn/xác nhận
  -> applyAiActions callable: đọc trạng thái mới, transaction, kết quả
```

Cloud Functions giữ `GEMINI_API_KEY` bằng secret. Client không gọi Gemini trực tiếp. Dùng `@google/genai` đã có trong Functions và structured JSON output; backend vẫn validate từng trường sau khi parse. Chọn model qua config backend, thử trên emulator và môi trường triển khai trước khi chốt tên model, fallback, timeout và chi phí. Tạo adapter riêng cho assistant trước; chỉ trích xuất phần chung từ receipt parser khi có test hồi quy cho quét hóa đơn.

### 3.1 `aiAssistant`

```ts
type SendInput = {
  requestId: string; // UUID ổn định cho cùng một lần gửi/retry
  householdId: string;
  message: string;   // trim, 1..1000 ký tự
  inputMode: "text" | "voice";
};
type SendResult = {
  messageId: string;
  reply: string;
  actions: ValidatedAction[];
  recipes: ValidatedRecipe[];
  quota: {used: number; limit: number | null; day: string};
};
```

1. Xác thực user, quyền household và input. Cùng `requestId` với payload khác phải bị từ chối.
2. Transaction giữ chỗ quota và tạo `users/{uid}/ai_requests/{requestId}` trạng thái `pending`; retry `completed` trả kết quả đã lưu, retry `pending` báo đang xử lý. Không gọi model bên trong transaction.
3. Đọc tối đa 150 item active theo hạn dùng, tối đa sáu lượt chat gần nhất. Context gửi model gồm alias ngắn, tên, lượng, đơn vị, ngày hết hạn, vị trí; không chứa UID/email. Nếu vượt giới hạn, nói rõ câu trả lời chỉ dựa trên một phần inventory; không khẳng định “không có” món nằm ngoài phần đã tải.
4. Gọi Gemini với system instruction riêng và JSON schema gọn. Giới hạn tổng thời gian, số lần retry cho lỗi tạm thời; ghi model thực dùng.
5. Validator kiểm tra câu trả lời, action, recipe, `ref`, số lượng, đơn vị và độ dài. Chuyển alias thành item ID, lưu `expectedUpdatedAt` (hoặc version) và snapshot số lượng/đơn vị cho mỗi action.
6. Transaction ghi một cặp user/assistant chat và chuyển request sang `completed`, lưu response để retry trả đúng cùng kết quả. Nếu request không còn `pending`, không ghi chat.
7. Khi model hoặc validation lỗi, transaction chuyển request sang `failed` và hoàn đúng quota đã giữ. Với request treo do Function chết/timeout, tác vụ dọn định kỳ chỉ hoàn request hết lease, chưa completed; hoàn đúng một lần bằng trạng thái trong transaction. Worker đến muộn không được hoàn tất request đã failed.

Ngày quota tính theo `Asia/Ho_Chi_Minh`. Lưu bộ đếm vào document **theo ngày** `users/{uid}/ai_usage_days/{YYYY-MM-DD}`, nên hoàn lượt hôm qua không đụng bộ đếm hôm nay. `ai_usage/current` hiện có cho receipt giữ nguyên; UI assistant đọc bộ đếm ngày hiện tại hoặc callable trả quota. Premium vẫn tạo request idempotency nhưng không tăng quota giới hạn.

`ai_requests/{requestId}` lưu `payloadHash`, `status`, `quotaDay`, `quotaReserved`, `leaseExpiresAt`, `messageId` và response/kết quả lỗi an toàn cho retry. `ai_usage_days/{day}` lưu `used` và `updatedAt`. Mọi chuyển trạng thái và tăng/giảm `used` ở cùng transaction; dọn request hết lease phải quét theo index phù hợp, có giới hạn batch và chỉ xử lý bản ghi còn `pending`.

### 3.2 Schema và prompt

```ts
type ModelReply = {
  reply: string;
  actions: Array<{
    type: "consume" | "discard" | "set_quantity" | "add_inventory";
    ref?: string; name?: string; quantity?: number; unit?: string;
    storageLocationId?: "fridge" | "freezer";
  }>;
  recipes: Array<{
    title: string; usesRefs: string[]; missingIngredients: string[];
    steps: string[]; cookingMinutes?: number;
  }>;
};
```

- Prompt yêu cầu tiếng Việt, trả lời dựa trên inventory được cung cấp, và nêu sự không chắc chắn khi thiếu context. Nội dung user và tên item đều là dữ liệu không đáng tin; không được ghi đè system instruction.
- Tối đa 10 action, ba recipe, mỗi recipe 12 bước. Backend bỏ ref lạ, trường thừa và output không hợp lệ; không lấy bất kỳ path Firestore hay quyền truy cập nào từ model.
- `consume/discard` thiếu hoặc vượt lượng, đơn vị lệch, nhiều batch không xác định: giữ đề xuất ở trạng thái `needsReview` và yêu cầu sửa; không mặc định “dùng hết”.
- `add_inventory` thiếu lượng/đơn vị/category/location hoặc không match master food chắc chắn: `needsReview`. Backend tính hạn dùng từ rule hiện có sau khi user đã bổ sung thông tin; user có thể sửa HSD trước xác nhận.
- Nếu không tìm được batch hoặc câu nói thiếu thông tin quan trọng, reply hỏi lại và không tạo action có thể áp dụng.

### 3.3 `applyAiActions`

```ts
type ApplyInput = {
  messageId: string;
  decisions: Array<{
    actionId: string; accept: boolean;
    quantity?: number; unit?: string; categoryId?: string;
    storageLocationId?: "fridge" | "freezer"; expirationDate?: string;
  }>;
};
```

- Xác thực user và household. Message thuộc user, có `actionStatus = proposed`, tạo chưa quá 30 phút. Chỉ dùng `actionId` từ đề xuất đã lưu; backend validate lại toàn bộ giá trị user sửa, whitelist field, giới hạn số decision và cấm ID trùng.
- **Trong cùng transaction**, đọc message và kiểm tra status lần nữa; đọc household và xác nhận caller vẫn là member, rồi đọc các item liên quan và giới hạn gói trước khi ghi. So `updatedAt`/version, số lượng, đơn vị và status với snapshot lúc đề xuất. Bất kỳ conflict nào trả `failed-precondition` cùng danh sách món cần xem lại; không áp dụng một phần trong bản đầu.
- Với nhiều batch FEFO, server tính phân bổ theo snapshot đã xác nhận và kiểm tra lại tất cả batch trong transaction. Không đổi đơn vị hoặc tự giảm lượng user yêu cầu.
- `consume/discard` trừ lượng hiện tại; khi về 0 đặt status tương ứng. `set_quantity` chỉ giảm hoặc đặt 0. Tính `remainingPercentage` bằng `initialQuantity`. `add_inventory` dùng chung logic tạo item, quyền, foodLimit và counter với `InventoryService`; refactor thành helper transaction được kiểm thử, không gọi một transaction lồng trong transaction khác.
- Đọc tất cả document cần thiết trước mọi lệnh ghi theo yêu cầu Firestore. Ghi item, household counter của item mới và `actionStatus = applied/dismissed` trong transaction. Trigger `onInventoryItemMutation` hiện có xử lý giảm counter khi item active chuyển sang consumed/discarded; không giảm lần thứ hai. Tài liệu hóa và kiểm thử tương tác này.
- Bấm xác nhận lần hai hoặc retry sau timeout: đọc `actionStatus` đã hoàn tất và trả kết quả đã lưu; tuyệt đối không ghi inventory lần nữa. Nếu tất cả bị bỏ chọn, chỉ đặt `dismissed`.

## 4. Firestore và bảo mật

| Path | Mục đích | Quyền client |
|---|---|---|
| `users/{uid}/ai_chats/{id}` | Tin chat, recipes, actions đã validate, trạng thái xác nhận, kết quả áp dụng | Owner đọc; không ghi |
| `users/{uid}/ai_requests/{requestId}` | Idempotency, lease, trạng thái xử lý, response, quota reservation | Không đọc/ghi trực tiếp |
| `users/{uid}/ai_usage_days/{day}` | Số lượt theo ngày VN | Owner đọc; không ghi |
| `memberships/{id}.aiAssistantDailyQuota` | Hạn mức, null = không giới hạn | Theo rules hiện có |
| `households/{id}/inventory_items/{itemId}.initialQuantity` | Mốc lượng ban đầu | Theo rules inventory được cập nhật có kiểm soát |

Document chat assistant lưu `requestId`, `householdId`, `actions`, `recipes`, `actionStatus`, `model`, `createdAt`; action lưu item ID và snapshot/version. Giới hạn 50 tin gần nhất, có chiến lược phân trang khi cần. Không lưu âm thanh; transcript chỉ được lưu khi user bấm Gửi. Thông báo cho user rằng nội dung chat và phần tồn kho liên quan được gửi đến dịch vụ AI.

Áp dụng App Check cho callable sau khi client đã tích hợp và test trên mọi nền tảng được hỗ trợ. Secret chỉ ở Functions; auth, household access, quota và validation đều ở backend. Không coi ẩn nút ở UI là kiểm soát quyền.

## 5. Flutter

- Hoàn thiện `lib/features/ai/` theo các lớp `domain/data/presentation` hiện có. Thêm entity `AiAction`, `AiRecipe`, mở rộng `AiChatMessage`, repository và use case `send/apply/watch`.
- Thêm route `/ai-assistant` và lối vào từ Home/Inventory; giữ bốn tab hiện có.
- Chat stream hiển thị 50 tin; send controller giữ cùng `requestId` khi retry. Disable nút gửi khi request đang xử lý, nhưng backend vẫn là nơi chống xử lý lặp.
- Voice service giữ một instance `SpeechToText`, xin quyền cần thiết, ưu tiên locale tiếng Việt nếu khả dụng; cho sửa transcript trước khi gửi. `inputMode` chỉ ghi cách nhập; sau khi bấm Gửi, text và speech chạy cùng provider, callable, quota, lịch sử và màn kết quả. Nếu mic/locale không khả dụng, ô text vẫn dùng được. Thêm quyền Android/iOS theo yêu cầu plugin và test máy thật.
- Action card hiển thị batch, HSD, lượng trước/sau và ô sửa cho `needsReview`. Không chọn sẵn action cần review. Sau conflict, làm mới tồn kho và yêu cầu user xác nhận lại.
- Recipe card hiển thị nguyên liệu dùng, nguyên liệu thiếu và bước nấu; chưa có nút ghi shopping list trong bản đầu.
- Hiển thị loading, lỗi, retry, quota và trạng thái `proposed/applied/dismissed/expired`; không hiển thị thành công cho action bị từ chối.

## 6. Thứ tự thực hiện

| Phase | Kết quả có thể demo | Điều kiện xong |
|---|---|---|
| 1. Chat AI + speech-to-text | Cùng màn chat hỏi tồn kho/hạn dùng bằng cách gõ hoặc nói; transcript sửa được trước khi gửi | Emulator test auth/household/quota/idempotency; test mic tiếng Việt, từ chối quyền và gửi bằng giọng nói trên thiết bị thật |
| 2. Recipe | Hỏi bằng gõ hoặc nói đều trả tối đa ba recipe có refs và nguyên liệu thiếu | Test không dùng item quá hạn, ref lạ, thiếu context |
| 3. Chuẩn hóa dữ liệu | `quantity/initialQuantity/remainingPercentage` và migration thống nhất | Test thêm/sửa/dùng hết item cũ và mới; rules cập nhật |
| 4. Cập nhật kho | Tin nhắn gõ hoặc nói đều tạo action card, xác nhận bằng transaction và xử lý conflict | Test FEFO nhiều batch, đổi unit, thay đổi đồng thời, retry/bấm đôi |
| 5. Tích hợp sau MVP | Thêm nguyên liệu thiếu vào shopping list | Chỉ bắt đầu khi PLAN 01 có repository/callable ổn định |

Không deploy production trong bước viết feature; quy trình deploy theo `docs/DEVELOPMENT_WORKFLOW.md`.

## 7. Kiểm thử và Definition of Done

- Backend unit: validator, FEFO, quota ngày VN, reservation/refund đúng một lần, request timeout, payload khác cùng requestId.
- Emulator integration: user khác household bị chặn; hai lần `applyAiActions` đồng thời chỉ ghi một lần; conflict item làm toàn transaction thất bại; foodLimit không vượt; counter active đúng.
- Flutter: model mapping, send retry cùng requestId, sửa transcript, action cần review, trạng thái lỗi/quota. Test cả gõ và nói trên cùng màn chat; microphone trên thiết bị thật.
- Câu demo: hỏi “Trong tủ còn gì sắp hết hạn?” bằng gõ **và bằng mic** cho cùng kiểu câu trả lời. Nói “Tôi vừa dùng 2 quả trứng và mua 1 kg thịt heo” tạo hai đề xuất; xác nhận chỉ thành công khi lượng, đơn vị, batch và category đã rõ. “Hôm nay nấu gì?” bằng gõ hoặc nói trả tối đa ba món ưu tiên thực phẩm sắp hết hạn.
- Chạy `dart format lib test`, `flutter analyze`, `flutter test`, `functions: npm run lint && npm test`; kiểm tra Rules bằng Emulator và chạy lại flow quét hóa đơn nếu đụng tới receipt parser.

## 8. Quyết định để nhóm xác nhận khi bắt đầu triển khai

1. Free quota khởi điểm: đề xuất **10 lượt thành công/ngày**, đọc từ membership config; Premium không giới hạn. Theo dõi chi phí và điều chỉnh sau pilot.
2. Khi item cũ có `remainingPercentage` không khớp `quantity`, migration sẽ ghi nhận và dùng mốc mới như mục 2.1; xác nhận với nhóm trước khi chạy trên dữ liệu production.
3. Household sharing về sau: hạn mức thêm món tính theo gói của owner hay người thực hiện cần chốt ở PLAN 05; AI dùng cùng quy tắc với đường thêm item thủ công, không tự tạo chính sách riêng.
