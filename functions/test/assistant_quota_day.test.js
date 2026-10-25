const assert = require("node:assert/strict");
const test = require("node:test");

const {
  assistantQuotaDay,
  replyForEmptyInventory,
  assistantModelError,
  requestedMenuDishCount,
  requestedServings,
} = require("../lib/ai/services/ai_assistant_service.js");

test("uses Vietnam day boundaries for assistant quota", () => {
  assert.equal(assistantQuotaDay(new Date("2026-10-22T16:59:59Z")), "2026-10-22");
  assert.equal(assistantQuotaDay(new Date("2026-10-22T17:00:00Z")), "2026-10-23");
});

test("answers empty fridge questions without generating a model response", () => {
  assert.match(replyForEmptyInventory(
    "Trong tủ còn thực phẩm nào sắp hết hạn?"), /chưa có thực phẩm nào/);
  assert.equal(replyForEmptyInventory("Tôi vừa mua 2 quả trứng"), null);
  assert.equal(replyForEmptyInventory("hãy nạp vào tủ lạnh của tôi 10 con gà"), null);
  assert.equal(replyForEmptyInventory("cho vào tủ 2 kg thịt heo"), null);
  assert.equal(replyForEmptyInventory("thêm 3 hộp sữa vào kho"), null);
  assert.equal(replyForEmptyInventory("Xin chào"), null);
});

test("maps Gemini payment errors to a useful callable error", () => {
  const error = assistantModelError({status: 402});
  assert.equal(error.code, "failed-precondition");
  assert.match(error.message, /thanh toán/);
});

test("recognizes multi-dish menus and serving counts", () => {
  assert.equal(requestedMenuDishCount("gợi ý thực đơn cho gia đình 4 người"), 2);
  assert.equal(requestedServings("gợi ý thực đơn cho gia đình 4 người"), 4);
  assert.equal(requestedMenuDishCount("thực đơn chứ không phải 1 món"), 2);
  assert.equal(requestedMenuDishCount("gợi ý 3 món cho bữa tối"), 3);
  assert.equal(requestedMenuDishCount("tôi nên nấu món gì?"), 0);
});
