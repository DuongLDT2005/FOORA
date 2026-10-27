const assert = require("node:assert/strict");
const test = require("node:test");

const {
  assistantQuotaDay,
  replyForEmptyInventory,
  assistantModelError,
  requestedMenuDishCount,
  requestedServings,
  promisesMissingReceipt,
  requestedFollowUpDishCount,
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

test("detects a reply that promises a receipt without actions", () => {
  assert.equal(promisesMissingReceipt({reply: "Tôi đã tạo phiếu trừ kho.",
    recipes: [], actions: []}), true);
  assert.equal(promisesMissingReceipt({reply: "Tôi đã tạo phiếu trừ kho.",
    recipes: [], actions: [{type: "consume"}]}), false);
  assert.equal(promisesMissingReceipt({reply: "Tủ còn 3 quả trứng.",
    recipes: [], actions: []}), false);
});

test("follow-ups on a dish suggestion must suggest dishes again", () => {
  const history = [
    {role: "user", text: "Nấu gì với đồ sắp hết hạn?"},
    {role: "assistant", text: "Có 2 món.", dishes: 2},
  ];
  assert.equal(requestedFollowUpDishCount("Điều chỉnh cho 4 người", history), 2);
  assert.equal(requestedFollowUpDishCount("nấu cho 4 người", history), 2);
  assert.equal(requestedFollowUpDishCount("Gợi ý món khác", history), 1);
  assert.equal(requestedFollowUpDishCount("Món nào nấu nhanh hơn?", history), 1);
  assert.equal(requestedFollowUpDishCount("Tủ còn gì?", history), 0);
  assert.equal(requestedFollowUpDishCount("Điều chỉnh cho 4 người",
    [{role: "assistant", text: "Tủ còn 3 quả trứng."}]), 0);
});
