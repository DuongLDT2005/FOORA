const assert = require("node:assert/strict");
const test = require("node:test");

const {validateAssistantResponse, convertRecipeAmount} =
  require("../lib/ai/services/ai_model_response.js");

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

test("keeps dish ingredients and amounts, mapping refs to item IDs", () => {
  const result = validateAssistantResponse(JSON.stringify({
    reply: "Bạn có thể làm trứng hấp.",
    actions: [],
    recipes: [{title: "Trứng hấp", servings: 2, steps: ["bị bỏ qua"],
      ingredients: [
        {name: "trứng", ref: "item1", quantity: 2},
        {name: "Hành lá", quantity: 1, unit: "nhánh"},
      ]}],
  }), inventory);
  const [recipe] = result.recipes;
  assert.equal(recipe.servings, 2);
  assert.deepEqual(recipe.ingredients, [
    {name: "Trứng", quantity: 2, unit: "quả", itemId: "fresh",
      expirationDate: "2026-10-26"},
    {name: "Hành lá", quantity: 1, unit: "nhánh"},
  ]);
  assert.equal(recipe.steps, undefined, "suggestions carry no cooking steps");
  assert.deepEqual(recipe.usesRefs, ["fresh"]);
  assert.deepEqual(recipe.usedIngredients, ["Trứng"]);
  assert.deepEqual(recipe.missingIngredients, ["Hành lá"]);
  assert.deepEqual(result.actions, [], "a suggestion never changes inventory");
});

test("drops recipes that reference expired or unknown items", () => {
  const result = validateAssistantResponse(JSON.stringify({
    reply: "Không nên dùng sữa cũ.",
    actions: [],
    recipes: [
      {title: "Sai", ingredients: [{name: "Sữa", ref: "item2", quantity: 1}]},
      {title: "Lạ", ingredients: [{name: "Gì đó", ref: "item9"}]},
      {title: "Rỗng", ingredients: []},
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

test("never converts units or assumes the whole batch (PLAN_04 §2.1)", () => {
  const result = validateAssistantResponse(JSON.stringify({
    reply: "Đề xuất trừ trứng.", recipes: [],
    actions: [
      {type: "consume", ref: "item1", quantity: 2, unit: "cái"},
      {type: "consume", ref: "item1"},
    ],
  }), inventory);
  const [otherUnit, noAmount] = result.actions;
  assert.equal(otherUnit.unit, "cái", "the spoken unit is kept");
  assert.equal(otherUnit.quantity, 2);
  assert.equal(otherUnit.reviewState, "needsReview");
  assert.equal(noAmount.quantity, undefined, "no default to the whole batch");
  assert.equal(noAmount.reviewState, "needsReview");
});

test("leaves consume batches to FEFO and targets only an unambiguous batch", () => {
  const twoBatches = [
    ...inventory,
    {...inventory[0], ref: "item3", itemId: "later", quantity: 10,
      initialQuantity: 10, expirationDate: "2026-11-05"},
  ];
  const result = validateAssistantResponse(JSON.stringify({
    reply: "Đề xuất.", recipes: [],
    actions: [
      {type: "consume", ref: "item1", quantity: 5, unit: "quả"},
      {type: "set_quantity", ref: "item1", quantity: 1, unit: "quả"},
    ],
  }), twoBatches);
  const [consume, setQuantity] = result.actions;
  assert.equal(consume.targetItemId, undefined);
  assert.deepEqual(consume.candidateBatches.map((item) => item.itemId),
    ["fresh", "later"]);
  assert.equal(consume.reviewState, "ready", "13 eggs cover 5 across batches");
  assert.equal(setQuantity.targetItemId, undefined,
    "two batches: the user must choose one");
  assert.equal(setQuantity.reviewState, "needsReview");
});

test("links an action without a usable ref by an unambiguous name", () => {
  const items = [...inventory,
    {ref: "item3", itemId: "beef", name: "Thịt bò", quantity: 500,
      unit: "g", expirationDate: "2026-10-30", isExpired: false,
      storageLocationId: "fridge", normalizedName: "thit bo",
      categoryId: "meat", initialQuantity: 500, updatedAtMillis: 1,
      createdAtMillis: 1},
    {ref: "item4", itemId: "pork", name: "Thịt heo", quantity: 300,
      unit: "g", expirationDate: "2026-10-30", isExpired: false,
      storageLocationId: "fridge", normalizedName: "thit heo",
      categoryId: "meat", initialQuantity: 300, updatedAtMillis: 1,
      createdAtMillis: 1}];
  const result = validateAssistantResponse(JSON.stringify({
    reply: "Đã tạo phiếu.", recipes: [], actions: [
      {type: "consume", ref: "", name: "thịt bò", quantity: 300, unit: "g"},
      {type: "consume", ref: "item99", name: "trứng", quantity: 2},
      {type: "consume", ref: "", name: "thịt", quantity: 100, unit: "g"},
    ],
  }), items);
  assert.deepEqual(result.actions.map((action) =>
    [action.name, action.candidateBatches.map((batch) => batch.itemId)]), [
    ["thịt bò", ["beef"]],
    ["trứng", ["fresh"]],
  ], "\"thịt\" names two kinds of items and is dropped, not guessed");
});

test("lists only food the fridge lacks as ingredients to buy", () => {
  const result = validateAssistantResponse(JSON.stringify({
    reply: "Bạn có thể làm trứng chiên.", actions: [],
    recipes: [{title: "Trứng chiên", ingredients: [
      {name: "trứng", quantity: 2},
      {name: "Sữa cũ", ref: "", quantity: 1},
      {name: "Nước mắm", quantity: 1, unit: "thìa"},
    ]}],
  }), inventory);
  const [recipe] = result.recipes;
  assert.deepEqual(recipe.ingredients, [
    {name: "Trứng", quantity: 2, unit: "quả", itemId: "fresh",
      expirationDate: "2026-10-26"},
    {name: "Sữa cũ", quantity: 1},
    {name: "Nước mắm", quantity: 1, unit: "thìa"},
  ]);
  assert.deepEqual(recipe.missingIngredients, ["Sữa cũ", "Nước mắm"],
    "expired stock still has to be bought; fresh stock never does");
});

test("converts recipe amounts between mass or volume units only", () => {
  assert.equal(convertRecipeAmount(0.3, "kg", "g"), 300);
  assert.equal(convertRecipeAmount(2, "lạng", "g"), 200);
  assert.equal(convertRecipeAmount(500, "ml", "L"), 0.5);
  assert.equal(convertRecipeAmount(2, "quả", "quả"), 2);
  assert.equal(convertRecipeAmount(1, "miếng", "g"), null);
  assert.equal(convertRecipeAmount(1, "kg", "ml"), null);
});

test("uses the fridge unit and moves the part above the stock to buy", () => {
  const items = [...inventory,
    {ref: "item3", itemId: "beef", name: "Thịt bò", quantity: 500,
      unit: "g", expirationDate: "2026-10-30", isExpired: false,
      storageLocationId: "fridge", normalizedName: "thit bo",
      categoryId: "meat", initialQuantity: 500, updatedAtMillis: 1,
      createdAtMillis: 1}];
  const result = validateAssistantResponse(JSON.stringify({
    reply: "Hai món.", actions: [], recipes: [
      {title: "Bò xào", servings: 4, ingredients: [
        {name: "Thịt bò", ref: "item3", quantity: 0.3, unit: "kg"},
        {name: "Trứng", ref: "item1", quantity: 5, unit: "quả"},
      ]},
      {title: "Bò kho", servings: 4, ingredients: [
        {name: "Thịt bò", ref: "item3", quantity: 1, unit: "miếng"},
      ]},
    ],
  }), items);
  const [stirFry, stew] = result.recipes;
  assert.deepEqual(stirFry.ingredients, [
    {name: "Thịt bò", quantity: 300, unit: "g", itemId: "beef",
      expirationDate: "2026-10-30"},
    {name: "Trứng", quantity: 3, unit: "quả", itemId: "fresh",
      expirationDate: "2026-10-26"},
    {name: "Trứng", quantity: 2, unit: "quả"},
  ]);
  assert.deepEqual(stirFry.missingIngredients, ["Trứng"]);
  assert.deepEqual(stew.ingredients, [
    {name: "Thịt bò", quantity: 1, unit: "miếng", itemId: "beef",
      expirationDate: "2026-10-30"},
  ], "units that cannot be converted are kept and not compared");
});
