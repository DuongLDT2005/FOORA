const assert = require("node:assert/strict");
const test = require("node:test");

const {validateAssistantResponse} = require("../lib/ai/services/ai_model_response.js");

const inventory = [
  {ref: "item1", itemId: "fresh", name: "Trứng", quantity: 3,
    unit: "quả", expirationDate: "2026-10-26", isExpired: false,
    storageLocationId: "fridge", normalizedName: "trung", categoryId: "eggs",
    initialQuantity: 5, updatedAtMillis: 1, createdAtMillis: 1},
  {ref: "item2", itemId: "expired", name: "Sữa cũ", quantity: 1,
    unit: "hộp", expirationDate: "2026-10-24", isExpired: true,
    storageLocationId: "fridge", normalizedName: "sua cu", categoryId: "milk",
    initialQuantity: 1, updatedAtMillis: 1, createdAtMillis: 1},
];

test("maps only usable recipe refs to stored inventory IDs", () => {
  const result = validateAssistantResponse(JSON.stringify({
    reply: "Bạn có thể làm trứng hấp.",
    actions: [],
    recipes: [{title: "Trứng hấp", usesRefs: ["item1"],
      missingIngredients: ["Hành"], steps: ["Đánh trứng", "Hấp chín"],
      cookingMinutes: 15}],
  }), inventory);
  assert.equal(result.recipes[0].usesRefs[0], "fresh");
  assert.deepEqual(result.recipes[0].usedIngredients, ["Trứng"]);
});

test("drops recipes that reference expired or unknown items", () => {
  const result = validateAssistantResponse(JSON.stringify({
    reply: "Không nên dùng sữa cũ.",
    actions: [],
    recipes: [
      {title: "Sai", usesRefs: ["item2"], missingIngredients: [], steps: ["Nấu"]},
      {title: "Lạ", usesRefs: ["item9"], missingIngredients: [], steps: ["Nấu"]},
    ],
  }), inventory);
  assert.deepEqual(result.recipes, []);
});

test("rejects malformed or oversized structured responses", () => {
  assert.equal(validateAssistantResponse("not json", inventory), null);
  assert.equal(validateAssistantResponse(JSON.stringify({reply: "", recipes: [], actions: []}),
    inventory), null);
  assert.equal(validateAssistantResponse(JSON.stringify({reply: "a", recipes: [{}, {}, {}, {}], actions: []}),
    inventory), null);
});

test("creates a reviewable inventory action from a known batch", () => {
  const result = validateAssistantResponse(JSON.stringify({
    reply: "Tôi có thể đề xuất trừ hai quả trứng.", recipes: [],
    actions: [{type: "consume", ref: "item1", quantity: 2, unit: "quả"}],
  }), inventory);
  assert.equal(result.actions.length, 1);
  assert.equal(result.actions[0].reviewState, "ready");
  assert.equal(result.actions[0].candidateBatches[0].itemId, "fresh");
  assert.equal(result.actions[0].resolution, "pending");
});

test("requires review for incomplete or truncated action context", () => {
  const json = JSON.stringify({reply: "Đề xuất dùng trứng.", recipes: [],
    actions: [{type: "consume", ref: "item1", quantity: 2, unit: "quả"}]});
  assert.equal(validateAssistantResponse(json, inventory, true).actions[0].reviewState,
    "needsReview");
});

test("keeps an add inventory proposal when the fridge is empty", () => {
  const result = validateAssistantResponse(JSON.stringify({
    reply: "Tôi đề xuất thêm 10 con gà vào tủ lạnh. Hãy xác nhận thông tin.",
    recipes: [],
    actions: [{type: "add_inventory", name: "Gà", quantity: 10,
      unit: "con", storageLocationId: "fridge"}],
  }), []);
  assert.equal(result.actions.length, 1);
  assert.equal(result.actions[0].type, "add_inventory");
  assert.equal(result.actions[0].quantity, 10);
  assert.equal(result.actions[0].unit, "con");
  assert.equal(result.actions[0].storageLocationId, "fridge");
  assert.equal(result.actions[0].reviewState, "needsReview");
  assert.deepEqual(result.actions[0].candidateBatches, []);
});
