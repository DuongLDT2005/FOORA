const assert = require("node:assert/strict");
const test = require("node:test");

const {
  validateImportItems,
  MAX_IMPORT_ITEMS,
} = require("../lib/shopping/services/shopping_validation.js");

const NOW = new Date("2026-10-29T03:00:00.000Z");

function item(overrides) {
  return {
    shoppingItemId: "item-1",
    storageLocationId: "fridge",
    categoryId: "dairy",
    actualQuantity: 2,
    ...overrides,
  };
}

test("accepts a valid payload and defaults purchaseDate to now", () => {
  const result = validateImportItems([item()], NOW);
  assert.equal(result.ok, true);
  assert.equal(result.value[0].purchaseDate.getTime(), NOW.getTime());
});

test("rejects empty, oversized and duplicate payloads", () => {
  assert.equal(validateImportItems([], NOW).ok, false);
  assert.equal(validateImportItems(undefined, NOW).ok, false);
  const tooMany = Array.from({length: MAX_IMPORT_ITEMS + 1}, (_, i) =>
    item({shoppingItemId: `item-${i}`}));
  assert.equal(validateImportItems(tooMany, NOW).ok, false);
  assert.equal(validateImportItems([item(), item()], NOW).ok, false);
});

test("rejects the old client field names", () => {
  const result = validateImportItems([{
    shoppingItemId: "item-1",
    quantity: 2,
    locationId: "fridge",
    categoryId: "dairy",
  }], NOW);
  assert.equal(result.ok, false);
});

test("rejects bad quantity, location, category and dates", () => {
  for (const bad of [
    {actualQuantity: 0},
    {actualQuantity: Number.NaN},
    {actualQuantity: 10001},
    {storageLocationId: "pantry"},
    {categoryId: ""},
    {categoryId: "other"},
    {purchaseDate: "not-a-date"},
    {purchaseDate: "2026-12-30T00:00:00.000Z"},
  ]) {
    assert.equal(validateImportItems([item(bad)], NOW).ok, false, JSON.stringify(bad));
  }
});

test("parses an ISO purchaseDate", () => {
  const result = validateImportItems(
    [item({purchaseDate: "2026-10-27T01:00:00.000Z"})],
    NOW
  );
  assert.equal(result.ok, true);
  assert.equal(result.value[0].purchaseDate.toISOString(), "2026-10-27T01:00:00.000Z");
});
