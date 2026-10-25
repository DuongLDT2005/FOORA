const assert = require("node:assert/strict");
const test = require("node:test");
const {suggestFoodCategoryId} = require("../lib/ai/services/ai_food_category.js");

test("suggests clear Vietnamese food categories", () => {
  assert.equal(suggestFoodCategoryId("gà"), "meat");
  assert.equal(suggestFoodCategoryId("thịt bò"), "meat");
  assert.equal(suggestFoodCategoryId("cua"), "seafood");
  assert.equal(suggestFoodCategoryId("rau muống"), "vegetables");
  assert.equal(suggestFoodCategoryId("cà chua"), "vegetables");
  assert.equal(suggestFoodCategoryId("nấm đùi gà"), "vegetables");
  assert.equal(suggestFoodCategoryId("vật phẩm không rõ"), null);
});
