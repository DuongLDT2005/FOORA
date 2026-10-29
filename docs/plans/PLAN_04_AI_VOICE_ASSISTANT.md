# PLAN 04 – Trợ lý AI cho FOORA

> Mục tiêu: chat tiếng Việt dựa trên tồn kho household, nhập câu hỏi bằng giọng nói, gợi ý món ưu tiên nguyên liệu sắp hết hạn, và **đề xuất** cập nhật kho để người dùng duyệt. Đây là kế hoạch triển khai; các con số quota và model là cấu hình ban đầu, cần kiểm tra lại trên môi trường chạy trước khi phát hành.

## Trạng thái triển khai (25/10/2026)

- Đã triển khai structured JSON cho reply/recipe/action, lọc context và lịch sử theo household, recipe card, action review sheet, callable `applyAiActions`, kiểm tra snapshot/FEFO/foodLimit và `initialQuantity` trên các đường tạo/sửa item. Client chỉ ghi kho sau khi người dùng xác nhận action.
- Đã thêm `firestore.indexes.json`, Rules, tài liệu dữ liệu, script backfill chạy trên Emulator và cấu hình `firebase.ai-test.json`. Kiểm tra: Functions 23 unit test, Flutter 112 test, Firestore Emulator cho apply đồng thời, retry, conflict, nhiều batch, giới hạn gói và migration mẫu.
- Còn phải thử mic tiếng Việt và xử lý từ chối quyền trên thiết bị thật; gọi model OpenRouter với secret thật để đo timeout/chi phí và xác nhận model; kiểm tra App Check trên các nền tảng trước khi bật enforcement; chạy backfill trên dữ liệu thật theo quy trình triển khai. Chưa deploy production hoặc tạo APK thử nghiệm trong đợt này.
- **29/10/2026 – Phase 5 xong:** recipe card có nút “Thêm vào danh sách mua” (chỉ khi có nguyên liệu cần mua và household đang hoạt động). Sheet `AddRecipeToShoppingSheet` cho chọn danh sách hoặc tạo danh sách mới “Nấu {món}”, bỏ tick và sửa số lượng/đơn vị; `BuildRecipeShoppingDraftsUseCase` điền lượng 1 / đơn vị `phần` khi thiếu, gộp nguyên liệu trùng và gắn `source: ai_recipe`; `ShoppingController.addItems` dùng lại cơ chế cộng dồn của PLAN 01, món lỗi không chặn món khác. Chỉ client, không callable/Rules mới, không trừ quota AI.

## 1. Hiện trạng trước đợt triển khai và phạm vi

- Đã có màn `/ai-assistant`, nhập text/mic tiếng Việt, transcript sửa trước khi gửi, lịch sử chat, quota theo ngày và callable `aiAssistant` được export. Đây là nền Phase 1, chưa đạt Definition of Done vì thiếu emulator integration test và kiểm tra mic trên thiết bị thật.
- Backend hiện trả text thuần với `actions: []`, `recipes: []`; chưa có structured JSON output/validator cho recipe và action, `applyAiActions` hay migration `initialQuantity`.
- Query lịch sử hiện giới hạn trước rồi mới lọc household; query inventory 150 item active theo hạn dùng có thể bị item quá hạn chiếm hết context. Sửa cả hai trước khi nghiệm thu Phase 1/2.
- Inventory, household mặc định, membership, receipt scan và payment đã có luồng riêng; AI phải dùng lại repository, constants và quy tắc hiện có.
- `speech_to_text` đã có trong `pubspec.yaml`; cần kiểm tra quyền và khả năng nhận tiếng Việt trên thiết bị thật.
- Shopping list thuộc PLAN 01. Chat, recipe và cập nhật inventory **không phụ thuộc** PLAN 01; chỉ nút “thêm nguyên liệu thiếu vào danh sách mua” (Phase 5) dùng API của nó.

### Phạm vi bản đầu

1. **Một màn chat AI có cả hai cách nhập ngay từ bản đầu:** gõ text hoặc bấm mic nói tiếng Việt. Speech-to-text đưa bản chép lời vào cùng ô chat để người dùng sửa; nút Gửi dùng chung luồng `aiAssistant`. Hỗ trợ hỏi tồn kho, số lượng, hạn dùng và món nên dùng trước bằng cả hai cách.
2. Gợi ý tối đa ba món dựa trên inventory active; chỉ ra nguyên liệu có và thiếu.
3. Đề xuất `consume`, `discard`, `set_quantity`, `add_inventory` từ tin nhắn gõ hoặc nói; chỉ cập nhật khi người dùng xác nhận.
4. Quota theo ngày cho lời gọi AI; lịch sử chat cá nhân. Chuyển giọng nói thành text chưa tốn quota, chỉ bấm Gửi mới tính lượt.

Voice luôn nghe, tự gửi lời nói, tự ghi kho, tư vấn y tế và thao tác shopping list nằm ngoài bản đầu.

## 2. Quy tắc dữ liệu cần thống nhất trước khi viết action

### 2.1 Số lượng và FEFO

- `inventory_items.quantity` là **số lượng còn hiện tại**, không phải số lượng mua ban đầu.
- Thêm `initialQuantity` là mốc để tính `remainingPercentage = round(quantity / initialQuantity * 100)`, giới hạn trong 0..100. Item active mới phải có `quantity > 0` và `initialQuantity = quantity`; khi `quantity = 0`, đặt phần trăm bằng 0 và status tương ứng, không chia cho 0. Không cho `initialQuantity <= 0` trên item active.
- Với item cũ thiếu `initialQuantity`: migration/backfill **trước phase cập nhật kho**; nếu `remainingPercentage > 0`, ước lượng `quantity / (remainingPercentage / 100)` và đánh dấu giá trị migration. Nếu không thể suy ra đáng tin cậy, dùng `quantity` làm mốc mới và ghi nhận việc reset phần trăm. Kiểm thử lại màn sửa item, status và mọi chỗ đọc `remainingPercentage`; cập nhật `DATABASE.md` và `firestore.rules`.
- Một `inventory_item` là một batch. Khi dùng nhiều batch cùng tên và **cùng đơn vị rõ ràng**, backend chia lượng trừ theo `expirationDate` tăng dần (FEFO), rồi `createdAt`/ID để có thứ tự ổn định. Nếu tên, batch hoặc đơn vị mơ hồ, yêu cầu người dùng chọn batch và lượng; không đoán. Chỉ cho chọn những batch ứng viên đã lưu cùng snapshot trong đề xuất; nếu cần batch khác, tạo đề xuất mới từ trạng thái kho mới.
- `set_quantity` đặt lượng còn lại cho **một batch được chọn rõ**. Nếu lời nói chỉ có tên và trùng nhiều batch, yêu cầu chọn batch. Không cho tăng số lượng qua `set_quantity`; mua thêm tạo batch mới qua `add_inventory`.
- Không tự đổi `kg/g`, `hộp/quả` hoặc cắt lượng yêu cầu theo lượng tồn. Khi thiếu lượng, vượt tồn, đơn vị không khớp hay confidence thấp: `needsReview`; user phải sửa hoặc bỏ action.

### 2.2 Recipe

- Chỉ item `active` và chưa quá hạn mới được đưa vào danh sách nguyên liệu có thể dùng; món quá hạn chỉ được nêu như cảnh báo. Khi kho vượt giới hạn context, ưu tiên item chưa quá hạn theo HSD gần nhất; không để item quá hạn chiếm hết 150 chỗ và không khẳng định đã xem toàn bộ kho.
- Recipe tối đa ba món, chỉ gồm tên món và tối đa 15 nguyên liệu kèm lượng/đơn vị theo khẩu phần (không có bước nấu); ưu tiên item sắp hết hạn. Nguyên liệu lấy từ kho phải có `ref` của item chưa quá hạn trong context; nguyên liệu cần mua không có `ref`, chưa tạo shopping item. Gợi ý món không bao giờ tạo action. Nấu xong, người dùng nói "Tôi đã nấu …, dùng …" (hoặc bấm "Tôi đã nấu món này" để soạn sẵn câu theo lượng gợi ý rồi sửa) và câu đó thành phiếu `consume` cần xác nhận; lịch sử chat gửi model kèm tóm tắt nguyên liệu của các món đã gợi ý để dùng khi người dùng không nói lượng.
- Recipe là gợi ý, không tự trừ kho. Nếu sau này thêm nút “Đã nấu món này”, nút đó đi qua cùng luồng đề xuất và xác nhận action.

## 3. Kiến trúc và hợp đồng API

```text
Flutter chat / voice transcript
  -> aiAssistant callable: auth, household, quota, context, model AI (Gemini), validator
  -> reply + recipe + action proposals (Firestore: client chỉ đọc)
  -> người dùng sửa/chọn/xác nhận
  -> applyAiActions callable: đọc trạng thái mới, transaction, kết quả
```

Cloud Functions giữ `GEMINI_API_KEY` bằng secret (dùng chung với quét hóa đơn). Client không gọi model trực tiếp. Model trả JSON theo `responseSchema`; backend vẫn validate từng trường sau khi parse. Chọn model qua config backend, thử trên emulator và môi trường triển khai trước khi chốt tên model, fallback, timeout và chi phí. Tạo adapter riêng cho assistant trước; chỉ trích xuất phần chung từ receipt parser khi có test hồi quy cho quét hóa đơn.

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
3. Lấy tối đa 150 item active: ưu tiên item **chưa quá hạn** theo HSD gần nhất; chỉ dùng chỗ còn lại cho một số item quá hạn để cảnh báo, không dùng chúng làm `usesRefs` của recipe. Lấy tối đa sáu lượt chat gần nhất **của đúng household trước khi limit**, giữ cặp user/assistant theo `requestId`; UI cũng query 50 tin của đúng household trước khi limit. Thêm composite index `householdId + createdAt` nếu query yêu cầu. Context gửi model gồm alias ngắn, tên, lượng, đơn vị, ngày hết hạn, vị trí; không chứa UID/email. Nếu vượt giới hạn, nói rõ câu trả lời chỉ dựa trên một phần inventory; không khẳng định “không có” món nằm ngoài phần đã tải.
4. Gọi Gemini: `AI_ASSISTANT_MODEL` trả lời trước, các model trong `AI_ASSISTANT_FALLBACK_MODELS` lần lượt chạy song song khi lượt trước lỗi, trả lời không dùng được hoặc quá 3.5s chưa trả lời (lấy câu trả lời hợp lệ đến trước); thinking ở mức thấp nhất, kho gửi dạng dòng gọn, không gọi lại lần hai khi thiếu món thực đơn. Theo phase: hoàn thiện chat với `actions: []`, `recipes: []`; Phase 2 mở recipe; Phase 4 mới mở action, tránh hiển thị đề xuất chưa có luồng duyệt. Giới hạn tổng thời gian, số lần retry cho lỗi tạm thời; ghi model thực dùng.
5. Validator kiểm tra các trường được mở ở phase hiện tại: câu trả lời; sau đó recipe và `usesRefs`; cuối cùng action, số lượng, đơn vị và `ref`. Khi mở action, chuyển alias thành item ID, lưu `expectedUpdatedAt` (hoặc version), snapshot số lượng/đơn vị và danh sách batch ứng viên có giới hạn cho mỗi action; nếu vượt giới hạn ứng viên, yêu cầu người dùng hỏi lại/chọn rõ hơn.
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
    title: string; servings?: number;
    ingredients: { name: string; ref?: string; quantity?: number; unit?: string }[];
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
    targetItemId?: string; // set_quantity hoặc chọn một batch rõ ràng
    batchAllocations?: Array<{itemId: string; quantity: number}>; // consume/discard nhiều batch
    name?: string; foodId?: string | null; // sửa add_inventory khi cần review
    quantity?: number; unit?: string; categoryId?: string;
    storageLocationId?: "fridge" | "freezer"; expirationDate?: string; // YYYY-MM-DD
  }>;
};
```

- Xác thực user và household. Message thuộc user, có `actionStatus = proposed`, tạo chưa quá 30 phút. Chỉ dùng `actionId` từ đề xuất đã lưu; backend validate lại toàn bộ giá trị user sửa, whitelist field, giới hạn số decision và cấm ID trùng. Gửi decision cho **mọi action** trong message; action không được chọn phải có `accept: false` để kết quả không mơ hồ.
- `targetItemId` chỉ hợp lệ cho `set_quantity` hoặc chọn một batch khi review; `batchAllocations` chỉ hợp lệ cho `consume/discard` nhiều batch. Chúng loại trừ nhau. Mọi ID phải nằm trong tập batch ứng viên, cùng household, tên/đơn vị khớp đề xuất và có snapshot lưu từ lúc đề xuất. Nếu không chọn thủ công, server chỉ tự phân bổ FEFO khi tên/đơn vị/lượng đã rõ và đủ tồn; tổng `batchAllocations.quantity` phải bằng lượng xác nhận. Batch ngoài tập ứng viên hoặc thiếu snapshot cần hỏi lại/tạo đề xuất mới.
- Khi người dùng sửa `name`/`foodId` của `add_inventory`, xác thực lại master food, category, location, đơn vị, HSD và foodLimit. Không lấy đường dẫn Firestore hoặc quyền từ quyết định hay model.
- **Trong cùng transaction**, đọc message và kiểm tra status lần nữa; đọc household và xác nhận caller vẫn là member, rồi đọc các item liên quan và giới hạn gói trước khi ghi. So `updatedAt`/version, số lượng, đơn vị và status với snapshot lúc đề xuất. Bất kỳ conflict nào trả `failed-precondition` cùng danh sách món cần xem lại; không áp dụng một phần trong bản đầu.
- Với nhiều batch FEFO, server tính phân bổ theo snapshot đã xác nhận và kiểm tra lại tất cả batch trong transaction. Không đổi đơn vị hoặc tự giảm lượng user yêu cầu.
- `consume/discard` trừ lượng hiện tại; khi về 0 đặt status tương ứng. `set_quantity` chỉ giảm hoặc đặt 0. Tính `remainingPercentage` bằng `initialQuantity`. `add_inventory` dùng chung logic tạo item, quyền, foodLimit và counter với `InventoryService`; refactor thành helper transaction được kiểm thử, không gọi một transaction lồng trong transaction khác.
- Đọc tất cả document cần thiết trước mọi lệnh ghi theo yêu cầu Firestore. Ghi item, household counter của item mới, kết quả từng action và `actionStatus = applied/dismissed` trong transaction. Trigger `onInventoryItemMutation` hiện có xử lý giảm counter khi item active chuyển sang consumed/discarded; không giảm lần thứ hai. Tài liệu hóa và kiểm thử tương tác này.
- Lưu `decisionsHash` từ payload đã chuẩn hóa và kết quả theo từng `actionId` trong cùng transaction. Bấm xác nhận lần hai hoặc retry sau timeout với **cùng** decisions: trả kết quả cũ; cùng `messageId` nhưng decisions khác: `failed-precondition`, tuyệt đối không ghi inventory lần nữa. Client giữ nguyên payload khi retry.
- Mỗi action lưu `reviewState = ready | needsReview` và `resolution = pending | applied | dismissed | expired`. Message `actionStatus = proposed | applied | dismissed | expired`: `applied` nếu có ít nhất một action được áp dụng; `dismissed` nếu tất cả bị bỏ. Kết quả từng action là nguồn để UI hiển thị trạng thái khi quyết định lẫn nhận/bỏ. Khi conflict, không ghi bất kỳ action nào, giữ đề xuất chưa áp dụng và yêu cầu lấy lại snapshot/xác nhận mới; khi quá 30 phút, từ chối và đánh dấu expired.

## 4. Firestore và bảo mật

| Path | Mục đích | Quyền client |
|---|---|---|
| `users/{uid}/ai_chats/{id}` | Tin chat, recipes, actions đã validate, trạng thái xác nhận, kết quả áp dụng | Owner đọc; không ghi |
| `users/{uid}/ai_requests/{requestId}` | Idempotency, lease, trạng thái xử lý, response, quota reservation | Không đọc/ghi trực tiếp |
| `users/{uid}/ai_usage_days/{day}` | Số lượt theo ngày VN | Owner đọc; không ghi |
| `memberships/{id}.aiAssistantDailyQuota` | Hạn mức, null = không giới hạn | Theo rules hiện có |
| `households/{id}/inventory_items/{itemId}.initialQuantity` | Mốc lượng ban đầu | Theo rules inventory được cập nhật có kiểm soát |

Document chat assistant lưu `requestId`, `householdId`, `actions`, `recipes`, `actionStatus`, `decisionsHash`/kết quả áp dụng khi đã quyết định, `model`, `createdAt`; mỗi action lưu ID batch ứng viên, snapshot/version, `reviewState` và `resolution`. Query 50 tin gần nhất **theo household** trước khi limit, có chiến lược phân trang khi cần. Không lưu âm thanh; transcript chỉ được lưu khi user bấm Gửi. Thông báo cho user rằng nội dung chat và phần tồn kho liên quan được gửi đến dịch vụ AI.

Áp dụng App Check cho callable sau khi client đã tích hợp và test trên mọi nền tảng được hỗ trợ. Secret chỉ ở Functions; auth, household access, quota và validation đều ở backend. Không coi ẩn nút ở UI là kiểm soát quyền.

## 5. Flutter

- Hoàn thiện `lib/features/ai/` theo các lớp `domain/data/presentation` hiện có. Thêm entity `AiAction`, `AiRecipe`, mở rộng `AiChatMessage`, repository và use case `send/apply/watch`.
- Thêm route `/ai-assistant` và lối vào từ Home/Inventory; giữ bốn tab hiện có.
- Chat stream hiển thị 50 tin; send controller giữ cùng `requestId` khi retry. Disable nút gửi khi request đang xử lý, nhưng backend vẫn là nơi chống xử lý lặp.
- Voice service giữ một instance `SpeechToText`, xin quyền cần thiết, ưu tiên locale tiếng Việt nếu khả dụng; cho sửa transcript trước khi gửi. `inputMode` chỉ ghi cách nhập; sau khi bấm Gửi, text và speech chạy cùng provider, callable, quota, lịch sử và màn kết quả. Nếu mic/locale không khả dụng, ô text vẫn dùng được. Thêm quyền Android/iOS theo yêu cầu plugin và test máy thật.
- Action card hiển thị batch, HSD, lượng trước/sau và ô sửa cho `needsReview`. Không chọn sẵn action cần review. Sau conflict, làm mới tồn kho và yêu cầu user xác nhận lại.
- Recipe card hiển thị nguyên liệu dùng, nguyên liệu thiếu và bước nấu. Từ Phase 5, nút “Thêm vào danh sách mua” mở sheet để người dùng chọn danh sách và món rồi mới ghi; AI không tự ghi shopping list.
- Hiển thị loading, lỗi, retry, quota và kết quả **từng action** (`pending/applied/dismissed/expired`); không hiển thị thành công cho action bị từ chối. Retry xác nhận giữ nguyên decisions để nhận lại đúng kết quả.

## 6. Thứ tự thực hiện

| Phase | Kết quả có thể demo | Điều kiện xong |
|---|---|---|
| 1. Hoàn thiện chat AI + speech-to-text (đang có nền) | Cùng màn chat hỏi tồn kho/hạn dùng bằng cách gõ hoặc nói; transcript sửa được trước khi gửi; lịch sử đúng household | Query history trước limit; structured reply với recipe/action rỗng; emulator test auth/household/quota/idempotency; test mic tiếng Việt và từ chối quyền trên thiết bị thật |
| 2. Recipe | Hỏi bằng gõ hoặc nói đều trả tối đa ba recipe có refs và nguyên liệu thiếu | Item còn dùng được được ưu tiên trong 150 context; test kho >150 item, item quá hạn, ref lạ, thiếu context |
| 3. Chuẩn hóa dữ liệu | `quantity/initialQuantity/remainingPercentage` và migration thống nhất | Dry-run/backfill và test thêm/sửa/dùng hết item cũ/mới; rules, tài liệu cập nhật |
| 4. Cập nhật kho | Tin nhắn gõ hoặc nói đều tạo action card, xác nhận bằng transaction và xử lý conflict | Chốt batch selection và kết quả từng action; test FEFO nhiều batch, unit, thay đổi đồng thời, retry cùng/khác decisions, bấm đôi |
| 5. Tích hợp sau MVP | Thêm nguyên liệu thiếu vào shopping list | Đã xong (29/10/2026): unit test build drafts/`addItems`, widget test nút trên recipe card và sheet |

Không deploy production trong bước viết feature; quy trình deploy theo `docs/DEVELOPMENT_WORKFLOW.md`.

### 6.1 Backlog có thể giao theo PR

Các PR dưới đây theo thứ tự phụ thuộc. Mỗi PR cập nhật `docs/DATABASE.md`, `docs/FUNCTIONS_GUIDE.md`, Rules/index nếu hợp đồng dữ liệu hoặc query đổi; nêu test đã chạy và phần cần thử trên máy thật.

1. **PR A — hoàn thiện Phase 1.** Sửa query history backend/Flutter thành lọc `householdId` trước `limit`; thêm index cần thiết. Tách adapter Gemini trả JSON với chỉ `reply` đang mở, kiểm tra reply và giữ `actions/recipes` rỗng. Test quota ngày Việt Nam, reservation/refund một lần, retry `requestId` cùng/khác payload, lease timeout, quyền household và history nhiều household; thử mic tiếng Việt/từ chối quyền trên máy thật. Xong khi cùng câu hỏi gõ/nói đi qua một callable, retry không tạo tin hoặc trừ quota hai lần.
2. **PR B — Phase 2 recipe.** Đổi cách chọn context để item chưa quá hạn được ưu tiên trong 150 chỗ; tách item quá hạn thành cảnh báo. Bật schema `recipes`, validate giới hạn, `usesRefs`, tên nguyên liệu thiếu và độ dài; map vào Firestore/Flutter và tạo recipe card. Test kho >150 item (kể cả nhiều item quá hạn), refs lạ, món thiếu nguyên liệu, dữ liệu không đầy đủ. Xong khi gõ/mic “Hôm nay nấu gì?” trả tối đa ba món có nguyên liệu dùng/thiếu và bước nấu, không tự trừ kho.
3. **PR C — Phase 3 số lượng.** Thêm `initialQuantity` ở đường thêm thủ công, receipt batch, model, form sửa, rules và tài liệu. Viết backfill có dry-run báo số item suy ra được, phải reset mốc, item số lượng 0/bất thường; kiểm thử trên dữ liệu Emulator trước khi chạy dữ liệu thật. Test invariant `quantity`, `initialQuantity`, `remainingPercentage` và status ở đường thêm/sửa/dùng hết. Xong khi mọi item active dùng cho action có `initialQuantity > 0` và phần trăm nhất quán; chạy production migration theo quy trình duyệt riêng.
4. **PR D — Phase 4 action.** Chốt `ValidatedAction` với batch ứng viên/snapshot, `reviewState`/`resolution`, hợp đồng quyết định ở mục 3.3 rồi mới mở `actions` từ model. Thêm `applyAiActions`, helper transaction dùng chung với inventory, FEFO, kiểm tra quyền/foodLimit, conflict và `decisionsHash`; Flutter có action card chọn/sửa/xác nhận và trạng thái từng action. Test 2 action nhận/bỏ lẫn nhau, nhiều batch/đơn vị, batch ngoài ứng viên, đồng thời hai lần apply, retry cùng/khác decisions, counter và receipt regression. Xong khi kho chỉ thay đổi sau xác nhận hợp lệ và mỗi action được áp dụng tối đa một lần.
5. **PR E — tích hợp và bàn giao.** Chạy toàn bộ unit/emulator/regression, kiểm tra mic trên thiết bị thật và chi phí/timeout model. Tích hợp App Check ở client, test trên mọi nền tảng được hỗ trợ rồi mới bật enforcement cho callable; kiểm tra lại Rules/index, hướng dẫn setup/demo và APK thử nghiệm. Shopping-list button đã làm sau khi PLAN 01 merge (Phase 5).

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
