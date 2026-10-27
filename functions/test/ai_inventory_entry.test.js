const assert = require("node:assert/strict");
const test = require("node:test");
const {parseInventoryEntry} = require("../lib/ai/services/ai_inventory_entry.js");
const {validateAssistantResponse} = require("../lib/ai/services/ai_model_response.js");

test("creates a five-line fridge receipt from the reported request", () => {
  const lines = parseInventoryEntry(
    "hãy nạp vào tủ lạnh của tôi 10kg cá, 10kg thịt, 5kg cà rốt, " +
    "4 kg khoai tây, 10 bó rau dùng cho cả tuần");
  assert.deepEqual(lines, [
    {name: "cá", quantity: 10, unit: "kg", storageLocationId: "fridge",
      categoryId: "seafood"},
    {name: "thịt", quantity: 10, unit: "kg", storageLocationId: "fridge",
      categoryId: "meat"},
    {name: "cà rốt", quantity: 5, unit: "kg", storageLocationId: "fridge",
      categoryId: "vegetables"},
    {name: "khoai tây", quantity: 4, unit: "kg", storageLocationId: "fridge",
      categoryId: "vegetables"},
    {name: "rau", quantity: 10, unit: "bó", storageLocationId: "fridge",
      categoryId: "vegetables"},
  ]);
  const validated = validateAssistantResponse(JSON.stringify({
    reply: "Kiểm tra phiếu nhập rồi xác nhận.", recipes: [],
    actions: lines.map((line) => ({type: "add_inventory", ...line})),
  }), []);
  assert.equal(validated.actions.length, 5);
  assert.ok(validated.actions.every((action) =>
    action.type === "add_inventory" && action.reviewState === "needsReview"));
  assert.equal(validated.actions[0].categoryId, "seafood");
});

test("does not turn read-only or mixed requests into an entry receipt", () => {
  assert.equal(parseInventoryEntry("Tủ còn 10 kg cá không?"), null);
  assert.equal(parseInventoryEntry("Tôi dùng 2 quả trứng và mua 1 kg thịt"), null);
  assert.equal(parseInventoryEntry("Hãy thêm cá vào tủ"), null);
  assert.equal(parseInventoryEntry("Hãy thêm 2 kg cá, 3 thịt"), null);
  assert.deepEqual(parseInventoryEntry("Tôi mới mua 1,5 kg cá"),
    [{name: "cá", quantity: 1.5, unit: "kg", storageLocationId: "fridge",
      categoryId: "seafood"}]);
  assert.deepEqual(parseInventoryEntry("hãy nạp vào tủ lạnh của tôi 10 con gà"),
    [{name: "gà", quantity: 10, unit: "con", storageLocationId: "fridge",
      categoryId: "meat"}]);
});

test("creates a four-line receipt for the latest purchase wording", () => {
  assert.deepEqual(parseInventoryEntry(
    "tôi mới mua về 1kg thịt heo, 2kg thịt bò, 2 bó rau, 5 lạng tôm"), [
    {name: "thịt heo", quantity: 1, unit: "kg", storageLocationId: "fridge",
      categoryId: "meat"},
    {name: "thịt bò", quantity: 2, unit: "kg", storageLocationId: "fridge",
      categoryId: "meat"},
    {name: "rau", quantity: 2, unit: "bó", storageLocationId: "fridge",
      categoryId: "vegetables"},
    {name: "tôm", quantity: 5, unit: "lạng", storageLocationId: "fridge",
      categoryId: "seafood"},
  ]);
});
