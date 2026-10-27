const assert = require("node:assert/strict");
const test = require("node:test");
const {parseInventoryConsume} =
  require("../lib/ai/services/ai_inventory_consume.js");

let next = 0;
const item = (name, quantity, unit, expirationDate, isExpired = false) => ({
  ref: `item${++next}`, itemId: `id${next}`, name, quantity, unit,
  expirationDate, isExpired, storageLocationId: "fridge",
  normalizedName: name.toLowerCase(), categoryId: "", initialQuantity: quantity,
  updatedAtMillis: 1, createdAtMillis: 1,
});
const inventory = [
  item("Trứng gà", 2, "quả", "2026-10-27"),
  item("Cá thu", 1, "con", "2026-10-28"),
  item("Cà rốt", 3, "củ", "2026-11-01"),
  item("Trứng gà", 10, "quả", "2026-11-05"),
  item("Thịt bò", 1, "kg", "2026-10-29"),
];

test("names the earliest batch and keeps the spoken amount and unit", () => {
  const result = parseInventoryConsume("Tôi vừa dùng 5 quả trứng gà", inventory);
  assert.deepEqual(result.proposals, [{type: "consume", ref: "item1",
    name: "Trứng gà", quantity: 5, unit: "quả"}]);
  const lang = parseInventoryConsume("Tôi vừa dùng 5 lạng thịt bò", inventory);
  assert.equal(lang.proposals[0].unit, "lạng", "no conversion to kg");
  assert.equal(lang.proposals[0].type, "consume", "\"bò\" is not \"bỏ\"");
});

test("tells accented words apart and never guesses", () => {
  const carrot = parseInventoryConsume("Tôi ăn 1 củ cà rốt", inventory);
  assert.equal(carrot.proposals[0].name, "Cà rốt");
  assert.equal(parseInventoryConsume("Tôi ăn 1 củ cà", inventory)
    .proposals[0].name, "Cà rốt", "\"cà\" never matches \"Cá thu\"");
  const withDuckEggs = [...inventory, item("Trứng vịt", 4, "quả", "2026-11-02")];
  assert.equal(parseInventoryConsume("Tôi dùng 1 quả trứng", withDuckEggs), null,
    "two different foods: the model asks which one");
  assert.equal(parseInventoryConsume("Tôi đã ăn 1 con cá", inventory)
    .proposals[0].name, "Cá thu");
});

test("discards with bỏ/vứt and leaves questions to the model", () => {
  assert.equal(parseInventoryConsume("Vứt 1 con cá thu", inventory)
    .proposals[0].type, "discard");
  assert.equal(parseInventoryConsume("Có nên ăn 2 quả trứng không?", inventory),
    null);
  assert.equal(parseInventoryConsume("Tôi vừa mua 2 quả trứng", inventory), null);
});

test("turns a cooking report into consume proposals", () => {
  const result = parseInventoryConsume(
    "Tôi đã nấu bò kho, dùng 0.5 kg thịt bò, 2 củ cà rốt", inventory);
  assert.deepEqual(result.proposals.map((proposal) =>
    [proposal.type, proposal.name, proposal.quantity, proposal.unit]), [
    ["consume", "Thịt bò", 0.5, "kg"],
    ["consume", "Cà rốt", 2, "củ"],
  ]);
});

test("leaves requests for dish ideas to the model", () => {
  assert.equal(parseInventoryConsume(
    "Gợi ý món ăn từ 2 quả trứng gà", inventory), null);
});
