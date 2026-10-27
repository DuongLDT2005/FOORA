const assert = require("node:assert/strict");
const test = require("node:test");
const {assignCatalogFood} = require("../lib/ai/services/ai_inventory_food.js");
const {toMasterFoodItem} = require("../lib/inventory/services/food_matcher.js");

const foods = [
  toMasterFoodItem("beef", {name: "Thịt bò", normalizedName: "thit bo",
    aliases: ["bò", "thịt bò úc"], categoryId: "meat", defaultUnit: "kg",
    photoUrl: "https://img.test/beef.png"}),
  toMasterFoodItem("water-spinach", {name: "Rau muống",
    normalizedName: "rau muong", aliases: ["rau muống nước"],
    categoryId: "vegetables", defaultUnit: "bó"}),
  toMasterFoodItem("dumplings", {name: "Há cảo đông lạnh",
    normalizedName: "ha cao dong lanh", aliases: [],
    categoryId: "frozen_foods", defaultUnit: "gói"}),
];

const add = (fields) => ({actionId: "a", type: "add_inventory",
  candidateBatches: [], reviewState: "needsReview", resolution: "pending",
  ...fields});

test("assigns the catalog food like receipt scanning", () => {
  const result = assignCatalogFood(add({name: "thịt bò", quantity: 1,
    unit: "kg", categoryId: "seafood"}), foods);
  assert.equal(result.foodId, "beef");
  assert.equal(result.name, "Thịt bò");
  assert.equal(result.categoryId, "meat", "catalog category wins");
  assert.equal(result.photoUrl, "https://img.test/beef.png");
  assert.equal(result.spokenName, undefined);
  assert.equal(result.storageLocationId, "fridge");
});

test("matches accented aliases and keeps what the user said", () => {
  const result = assignCatalogFood(add({name: "rau muống nước", quantity: 2}),
    foods);
  assert.equal(result.foodId, "water-spinach");
  assert.equal(result.name, "Rau muống");
  assert.equal(result.spokenName, "rau muống nước");
  assert.equal(result.unit, "bó", "default unit fills a missing unit");
});

test("frozen foods default to the freezer unless a place was given", () => {
  assert.equal(assignCatalogFood(add({name: "há cảo đông lạnh", quantity: 1}),
    foods).storageLocationId, "freezer");
  assert.equal(assignCatalogFood(add({name: "há cảo đông lạnh", quantity: 1,
    storageLocationId: "fridge"}), foods).storageLocationId, "fridge");
});

test("unknown foods keep their name and get a heuristic category", () => {
  const result = assignCatalogFood(add({name: "Cá thu", quantity: 1,
    unit: "con"}), foods);
  assert.equal(result.foodId, undefined);
  assert.equal(result.name, "Cá thu");
  assert.equal(result.categoryId, "seafood");
  assert.ok(!Object.values(result).includes(undefined),
    "Firestore rejects undefined fields");
});

test("other action types are left untouched", () => {
  const consume = {...add({name: "thịt bò"}), type: "consume"};
  assert.equal(assignCatalogFood(consume, foods), consume);
});
