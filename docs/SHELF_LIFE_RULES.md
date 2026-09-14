# Bảng Tiêu Chuẩn Thời Hạn Bảo Quản Thực Phẩm (Shelf-Life Rules)
> **Nguồn tham chiếu chuẩn**: Cục Quản lý Thực phẩm và Dược phẩm Hoa Kỳ (**U.S. FDA**) & Bộ Nông nghiệp Hoa Kỳ (**USDA Food Safety and Inspection Service**) - *Cập nhật theo biểu đồ Refrigerator & Freezer Storage Chart*.

Tài liệu này tổng hợp thời gian lưu trữ an toàn thực phẩm trong **Ngăn mát (Refrigerator, 4°C / 40°F)** và **Ngăn đông (Freezer, -18°C / 0°F)** nhằm đảm bảo chất lượng, dinh dưỡng và phòng ngừa ngộ độc thực phẩm.

---

## 1. Nguyên Tắc Bảo Quản Cốt Lõi (FDA Guidelines)

- **Ngăn mát (4°C / 40°F)**: Làm chậm sự phát triển của vi khuẩn. Thời hạn lưu trữ ở ngăn mát là **giới hạn an toàn nghiêm ngặt** (sau thời gian này thực phẩm có nguy cơ nhiễm khuẩn gây hại dù chưa bốc mùi rõ rệt).
- **Ngăn đông (-18°C / 0°F)**: Đóng băng hoàn toàn hoạt động của vi khuẩn. Về mặt an toàn vi sinh vật, thực phẩm đông lạnh liên tục ở -18°C có thể để vô thời hạn; tuy nhiên **thời hạn ngăn đông ở bảng này là mốc chất lượng tối ưu** (sau mốc này thực phẩm bị khô, mất nước, biến tính đạm, cháy lạnh - *freezer burn*).
- **Bao gói**: Nếu cấp đông thịt/cá trên 2 tháng, nên bọc thêm màng bọc thực phẩm kín khí, giấy bạc hoặc túi zip chuyên dụng để tránh cháy lạnh.
- **Quy chuẩn lưu trữ Database FOORA**:
  Mỗi rule trong hệ thống được cấu trúc linh hoạt theo đơn vị thời gian tự nhiên:
  - `minValue`: Thời gian tối thiểu (Number hoặc `null` nếu không khuyến nghị)
  - `maxValue`: Thời gian tối đa (Number hoặc `null` nếu không khuyến nghị)
  - `unit`: Đơn vị thời gian (`'days'`, `'weeks'`, `'months'`, `'years'` hoặc `null`)
  
  *Ví dụ*:
  - Cấp đông thịt bò (4 – 12 tháng): `{ minValue: 4, maxValue: 12, unit: 'months' }` (không phải ghi `120 – 365 ngày`)
  - Ngăn mát trứng gà (3 – 5 tuần): `{ minValue: 3, maxValue: 5, unit: 'weeks' }` (thay vì `21 – 35 ngày`)
  - Ngăn mát thịt tươi (3 – 5 ngày): `{ minValue: 3, maxValue: 5, unit: 'days' }`
  - Trứng tươi cấp đông: `{ minValue: null, maxValue: null, unit: null }` (không khuyến nghị cấp đông)

---

## 2. Bảng Tổng Hợp Chi Tiết Theo Nhóm Thực Phẩm

### 2.1. Trứng (Eggs)

| Phân loại thực phẩm | Ngăn mát (`fridge` - 4°C) | Ngăn đông (`freezer` - -18°C) | Lưu ý an toàn & Bảo quản |
| :--- | :--- | :--- | :--- |
| **Trứng tươi nguyên vỏ** (*Fresh, in shell*) | 3 – 5 tuần | **Không cấp đông** (*Don't freeze*) | Cấp đông nguyên quả làm nứt vỏ, vi khuẩn xâm nhập |
| **Lòng đỏ / Lòng trắng trứng sống** (*Raw yolks, whites*) | 2 – 4 ngày | 12 tháng (1 năm) | Đánh nhẹ lòng đỏ với ít muối/đường trước khi đông để không quánh |
| **Trứng luộc chín** (*Hard-cooked*) | 1 tuần (7 ngày) | **Không cấp đông** (*Don't freeze*) | Cấp đông làm lòng trắng bị dai xốp và rỉ nước |
| **Trứng thanh trùng dạng lỏng** (Mở nắp) | 3 ngày | **Không cấp đông** | Dùng hết nhanh sau khi mở hộp |
| **Trứng thanh trùng dạng lỏng** (Chưa mở) | 10 ngày | 12 tháng (1 năm) | Giữ nguyên bao bì niêm phong |
| **Món trứng đã nấu chín** (*Cooked egg dishes*) | 3 – 4 ngày | **Không khuyến nghị** | Trứng ốp la, chả trứng, canh trứng |

---

### 2.2. Thịt Tươi Nguyên Miếng - Bò, Bê, Heo, Cừu (Fresh Meat)

| Phân loại thực phẩm | Ngăn mát (`fridge` - 4°C) | Ngăn đông (`freezer` - -18°C) | Ví dụ món trong FOORA |
| :--- | :--- | :--- | :--- |
| **Thịt bít tết / Thăn bò** (*Steaks*) | 3 – 5 ngày | 4 – 12 tháng | `beef-tenderloin`, `beef-chuck` |
| **Sườn / Thịt sườn** (*Chops*) | 3 – 5 ngày | 4 – 12 tháng | `pork-ribs`, `lamb-chops`, `beef-ribs` |
| **Thịt tảng / Thịt nướng / Bắp** (*Roasts*) | 3 – 5 ngày | 4 – 12 tháng | `beef-shank`, `pork-shoulder`, `pork-leg` |
| **Thịt ba chỉ** (*Belly / Short plate*) | 3 – 5 ngày | 4 – 6 tháng | `pork-belly`, `beef-short-plate` |
| **Nội tạng / Bộ phận phụ** (*Gan, tim, thận, lưỡi, dạ dày, lòng*) | 1 – 2 ngày | 3 – 4 tháng | `pork-liver`, `pork-heart`, `pork-intestines`, `beef-tripe` |

---

### 2.3. Thịt Xay, Thịt Băm & Thịt Làm Món Hầm (Ground & Stew Meat)

> ⚠️ *Thịt xay có diện tích tiếp xúc không khí lớn hơn nhiều so với thịt nguyên miếng nên nguy cơ nhiễm khuẩn cao hơn hẳn.*

| Phân loại thực phẩm | Ngăn mát (`fridge` - 4°C) | Ngăn đông (`freezer` - -18°C) | Ví dụ món trong FOORA |
| :--- | :--- | :--- | :--- |
| **Thịt bò xay / Thịt làm hamburger** | 1 – 2 ngày | 3 – 4 tháng | `minced-beef` |
| **Thịt heo xay, bê xay, cừu xay** | 1 – 2 ngày | 3 – 4 tháng | `minced-pork` |
| **Thịt gia cầm xay** (Gà xay, gà băm) | 1 – 2 ngày | 3 – 4 tháng | `minced-chicken` |
| **Thịt cắt khúc nấu hầm** (*Stew meats*) | 1 – 2 ngày | 3 – 4 tháng | Thịt bò kho, bò sốt vang |
| **Giò sống / Mọc** (*Meat paste*) | 1 – 2 ngày | 2 – 3 tháng | `pork-paste` |

---

### 2.4. Thịt Gia Cầm Tươi (Fresh Poultry)

| Phân loại thực phẩm | Ngăn mát (`fridge` - 4°C) | Ngăn đông (`freezer` - -18°C) | Ví dụ món trong FOORA |
| :--- | :--- | :--- | :--- |
| **Gia cầm nguyên con** (*Whole chicken/turkey/duck*) | 1 – 2 ngày | 12 tháng (1 năm) | `whole-chicken`, `duck-meat`, `pigeon-meat` |
| **Gia cầm chia phần** (Ức, đùi, cánh, chân) | 1 – 2 ngày | 9 tháng | `chicken-breast`, `chicken-thigh`, `chicken-wings`, `chicken-feet`, `duck-thigh` |
| **Lòng mề gia cầm** (*Giblets: gan, tim, mề*) | 1 – 2 ngày | 3 – 4 tháng | `chicken-giblets` |

---

### 2.5. Thủy Hải Sản Tươi & Đã Chế Biến (Fish & Shellfish)

| Phân loại thực phẩm | Ngăn mát (`fridge` - 4°C) | Ngăn đông (`freezer` - -18°C) | Lưu ý & Ví dụ FOORA |
| :--- | :--- | :--- | :--- |
| **Cá béo tươi** (*Cá hồi, cá thu, cá ngừ, cá tra, cá basa, cá đối*) | 1 – 3 ngày | 2 – 3 tháng | `salmon`, `tuna-fish`, `mackerel`, `basa-fish` |
| **Cá nạc tươi** (*Cá tuyết, cá bơn, cá chẽm, cá lóc, cá điêu hồng, cá rô phi*) | 1 – 2 ngày | 4 – 8 tháng | `tilapia`, `red-tilapia`, `seabass`, `snakehead-fish` |
| **Tôm tươi & Tôm đồng** (*Shrimp, Crayfish*) | 3 – 5 ngày | 6 – 18 tháng | `black-tiger-shrimp`, `white-shrimp`, `giant-river-prawn` |
| **Mực tươi** (*Squid*) | 1 – 3 ngày | 6 – 18 tháng | `squid-tube`, `cuttlefish` (mực nang) |
| **Nghêu, Sò, Hàu sống nguyên vỏ** (*Live Clams, Oysters*) | 5 – 10 ngày | **Không khuyến nghị** | Giữ ẩm mát, không cấp đông sống nguyên vỏ |
| **Nghêu, Sò, Hàu đã tách thịt** (*Shucked*) | 3 – 10 ngày | 3 – 4 tháng | `clams`, `oyster`, `blood-cockle`, `hairy-ark-clam` |
| **Cua & Tôm hùm sống** (*Live Crab, Lobster*) | 1 ngày | **Không khuyến nghị** | Phải chế biến ngay trong 24h khi còn sống |
| **Thịt cua tươi & Tôm hùm sơ chế** | 2 – 4 ngày | 2 – 4 tháng | `mud-crab`, `swimmer-crab` |
| **Cá đã nấu chín** (*Cooked fish*) | 3 – 4 ngày | 4 – 6 tháng | Cá kho, cá chiên còn thừa |
| **Cá hun khói** (*Smoked fish*) | 2 tuần (14 ngày) | 2 tháng | Cá hồi hun khói |
| **Hải sản đóng hộp** (Mở nắp, chuyển ra hộp bảo quản) | 3 – 4 ngày | 2 tháng | Cá hộp Ba Cô Gái, cá ngừ ngâm dầu |

---

### 2.6. Thịt Chế Biến Sẵn, Xúc Xích, Giăm Bông, Đồ Nguội (Processed Meats)

| Phân loại thực phẩm | Ngăn mát (`fridge` - 4°C) | Ngăn đông (`freezer` - -18°C) | Lưu ý đóng gói & Bảo quản |
| :--- | :--- | :--- | :--- |
| **Thịt ba rọi xông khói** (*Bacon*) | 1 tuần (7 ngày) | 1 tháng | Bọc kín sau khi mở gói |
| **Xúc xích tươi sống** (*Raw sausage*) | 1 – 2 ngày | 1 – 2 tháng | Xúc xích tươi heo/bò/gà chưa qua nhiệt |
| **Xúc xích đã nấu chín hoàn toàn** (*Fully cooked*) | 1 tuần (7 ngày) | 1 – 2 tháng | Xúc xích xông khói, xúc xích Đức chín |
| **Xúc xích mua đông lạnh** (*Purchased frozen*) | Sau nấu: 3 – 4 ngày | 1 – 2 tháng | Tính từ ngày mua |
| **Xúc xích tiệt trùng Summer sausage** | Chưa mở: 3 tháng<br>Mở gói: 3 tuần | 1 – 2 tháng | Nhãn "Keep Refrigerated" |
| **Hot dog / Xúc xích cây** (Chưa mở gói) | 2 tuần | 1 – 2 tháng | Nguyên seal bao bì |
| **Hot dog / Xúc xích cây** (Đã mở gói) | 1 tuần | 1 – 2 tháng | Gói kín sau khi mở |
| **Thịt nguội / Giăm bông lát** (*Lunch meats* - Chưa mở) | 2 tuần | 1 – 2 tháng | Chả lụa, dăm bông lát đóng gói |
| **Thịt nguội / Giăm bông lát** (*Lunch meats* - Đã mở) | 3 – 5 ngày | 1 – 2 tháng | Bọc kín tránh nhiễm khuẩn Listeria |
| **Ham tươi chưa ướp muối, sống** (*Fresh, uncured, raw*) | 3 – 5 ngày | 6 tháng | |
| **Ham tươi chưa ướp muối, đã nấu chín** | 3 – 4 ngày | 3 – 4 tháng | |
| **Ham muối cần nấu chín** (*Cured, cook-before-eating*) | 5 – 7 ngày | 3 – 4 tháng | |
| **Ham chín hút chân không tại nhà máy** (Chưa mở) | 2 tuần | 1 – 2 tháng | |
| **Ham chín nguyên khối bọc màng siêu thị** | 1 tuần (7 ngày) | 1 – 2 tháng | |
| **Ham chín cắt lát, nửa khối bọc màng siêu thị** | 3 – 5 ngày | 1 – 2 tháng | |
| **Giăm bông khô cao cấp** (*Prosciutto, Parma cut*) | 2 – 3 tháng | 1 tháng | Thịt muối sấy khô kiểu Âu |
| **Thịt hộp nhãn "Keep Refrigerated"** (Chưa mở) | 6 – 9 tháng | **Không cấp đông** | Bảo quản ngăn mát |
| **Thịt hộp nhãn "Keep Refrigerated"** (Đã mở) | 3 – 5 ngày | 1 – 2 tháng | Phải san ra hũ có nắp |
| **Thịt bò muối đóng túi kèm nước ngâm** (*Corned beef*) | 5 – 7 ngày | 1 tháng | Rút cạn nước ngâm trước khi đông lạnh |

---

### 2.7. Thức Ăn Nấu Chín, Thức Ăn Thừa & Món Ăn Nhanh (Leftovers & Convenience)

| Phân loại thực phẩm | Ngăn mát (`fridge` - 4°C) | Ngăn đông (`freezer` - -18°C) | Lưu ý bảo quản |
| :--- | :--- | :--- | :--- |
| **Món thịt & gia cầm nấu chín thừa** (*Leftovers*) | 3 – 4 ngày | 2 – 6 tháng | Chia phần nhỏ để nguội nhanh trước khi cất |
| **Nước sốt thịt, nước hầm xương** (*Gravy & broth*) | 1 – 2 ngày | 2 – 3 tháng | Rất dễ ôi thiu do giàu đạm lỏng |
| **Gà rán** (*Fried chicken*) | 3 – 4 ngày | 4 tháng | Giữ ráo dầu trước khi bảo quản |
| **Gia cầm phủ sốt / nước thịt** (*Poultry in gravy*) | 3 – 4 ngày | 6 tháng | Nước sốt giúp giữ ẩm tốt khi đông lạnh |
| **Nugget gà, chả gà viên** (*Nuggets, patties*) | 3 – 4 ngày | 1 – 3 tháng | |
| **Pizza thừa** (*Leftover pizza*) | 3 – 4 ngày | 1 – 2 tháng | Bọc giấy bạc hoặc hộp kín |
| **Canh, súp, món tiềm** (*Soups & Stews*) | 3 – 4 ngày | 2 – 3 tháng | Cả súp rau củ lẫn súp có thịt |
| **Salad deli** (Salad trứng, gà, cá ngừ, macaroni) | 3 – 4 ngày | **Không cấp đông** | Sốt mayonnaise bị tách nước dầu khi đông lạnh |
| **Thịt nhồi sẵn sốt/rau chưa nấu** (*Pre-stuffed*) | 1 ngày | **Không cấp đông** | Rau củ nhồi chảy nước, nhiễm khuẩn chéo |
| **Món đút lò / Casseroles có trứng** (Sau khi nướng) | 3 – 4 ngày | 2 – 3 tháng | |
| **Bánh Quiche mặn có nhân** (Sau khi nướng) | 3 – 5 ngày | 2 – 3 tháng | |

---

### 2.8. Sữa, Bơ, Phô Mai, Dầu Mỡ & Đồ Uống (Dairy, Fats & Juices)

| Phân loại thực phẩm | Ngăn mát (`fridge` - 1-7°C) | Ngăn đông (`freezer` - -18°C) | Lưu ý & Ví dụ FOORA |
| :--- | :--- | :--- | :--- |
| **Sữa tươi** (*Fresh milk*) | 5 – 7 ngày | 1 – 3 tháng | Cấp đông có thể tách béo, lắc đều trước khi dùng để nấu/baking |
| **Kem tươi / Whipping cream** | 5 – 7 ngày | Không khuyến nghị | Kem lỏng đông đá sẽ bị tách nước, không đánh bông lại được |
| **Phô mai cứng / bán cứng** (*Cheddar, Parmesan, Gouda*) | 1 – 3 tháng | 6 tháng | `cheddar-cheese`, `parmesan-cheese`, `mozzarella-cheese` |
| **Phô mai mềm** (*Ricotta, Cream cheese, Phô mai tươi*) | 1 – 2 tuần | Không khuyến nghị | Cấp đông làm thay đổi kết cấu hạt và chảy nước |
| **Bơ động vật** (*Butter*) | 8 tuần (2 tháng) | 6 – 9 tháng | Cấp đông rất tốt, giữ nguyên hương vị bơ |
| **Bơ thực vật** (*Margarine*) | 6 tháng | 12 tháng (1 năm) | `margarine` |
| **Dầu ăn, mỡ động vật** (*Cooking oil, Lard*) | 6 tháng | Không cần cấp đông | Bảo quản kín tránh bị oxy hóa (gắt dầu) |
| **Nước ép trái cây tươi** (*Fruit juice*) | 1 – 2 tuần (7-14 ngày) | 8 – 12 tháng | Nước cam, nước bưởi, nước táo |

---

## 3. Bảng Tra Cứu Nhanh Theo Nhóm Áp Dụng Cho Database FOORA

```text
+-----------------------------------------------------+-----------------------+--------------------------+
| Nhóm Thực Phẩm                                      | Ngăn mát (fridge)     | Ngăn đông (freezer)      |
+-----------------------------------------------------+-----------------------+--------------------------+
| Thịt xay / Thịt băm (Heo, Bò, Gà)                   | 1 - 2 ngày            | 3 - 4 tháng              |
| Lòng, mề, gan, tim, nội tạng                        | 1 - 2 ngày            | 3 - 4 tháng              |
| Thịt gia cầm tươi nguyên con (Gà, Vịt)              | 1 - 2 ngày            | 12 tháng (1 năm)         |
| Thịt gia cầm chia phần (Ức, đùi, cánh)              | 1 - 2 ngày            | 9 tháng                  |
| Cá béo tươi (Cá hồi, cá thu, cá basa, cá ngừ)       | 1 - 3 ngày            | 2 - 3 tháng              |
| Cá nạc tươi (Cá lóc, điêu hồng, rô phi, chẽm)       | 1 - 2 ngày            | 4 - 8 tháng              |
| Tôm tươi, tôm đồng, tôm càng                        | 3 - 5 ngày            | 6 - 18 tháng             |
| Mực tươi (Mực ống, mực nang)                        | 1 - 3 ngày            | 6 - 18 tháng             |
| Nghêu, Sò, Hàu sống nguyên vỏ                       | 5 - 10 ngày           | Không khuyến nghị        |
| Nghêu, Sò, Hàu đã tách thịt (Shucked)               | 3 - 10 ngày           | 3 - 4 tháng              |
| Cua, Tôm hùm tươi sống                              | 1 ngày                | Không khuyến nghị        |
| Thịt cua tươi, tôm hùm sơ chế                       | 2 - 4 ngày            | 2 - 4 tháng              |
| Thịt bò/heo tươi nguyên miếng, sườn, bắp            | 3 - 5 ngày            | 4 - 12 tháng             |
| Thức ăn chín thừa (Thịt, gia cầm)                   | 3 - 4 ngày            | 2 - 6 tháng              |
| Canh, Súp, Món hầm                                  | 3 - 4 ngày            | 2 - 3 tháng              |
| Pizza thừa                                          | 3 - 4 ngày            | 1 - 2 tháng              |
| Nước hầm xương, Nước sốt thịt                       | 1 - 2 ngày            | 2 - 3 tháng              |
| Trứng tươi nguyên quả                               | 3 - 5 tuần            | Không cấp đông           |
| Trứng luộc chín                                     | 1 tuần (7 ngày)       | Không cấp đông           |
| Bacon, Xúc xích xông khói, Xúc xích chín            | 1 tuần (7 ngày)       | 1 - 2 tháng              |
| Xúc xích tươi sống                                  | 1 - 2 ngày            | 1 - 2 tháng              |
| Thịt nguội / Giăm bông lát (Đã mở gói)              | 3 - 5 ngày            | 1 - 2 tháng              |
| Thịt nguội / Giăm bông lát (Chưa mở gói)            | 2 tuần (14 ngày)      | 1 - 2 tháng              |
| Giăm bông khô cao cấp (Prosciutto, Parma)           | 2 - 3 tháng           | 1 tháng                  |
| Sữa tươi                                            | 5 - 7 ngày            | 1 - 3 tháng              |
| Kem tươi, Whipping cream                            | 5 - 7 ngày            | Không khuyến nghị        |
| Phô mai cứng (Cheddar, Parmesan)                    | 1 - 3 tháng           | 6 tháng                  |
| Bơ động vật                                         | 8 tuần (~2 tháng)     | 6 - 9 tháng              |
| Bơ thực vật (Margarine)                             | 6 tháng               | 12 tháng (1 năm)         |
| Dầu ăn, mỡ lợn                                      | 6 tháng               | Không cần cấp đông       |
| Nước ép trái cây tươi                               | 1 - 2 tuần            | 8 - 12 tháng             |
+-----------------------------------------------------+-----------------------+--------------------------+
```
