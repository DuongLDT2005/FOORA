const assert = require("node:assert/strict");
const test = require("node:test");

const {inferInitialQuantity} = require("../lib/inventory/services/initial_quantity.js");

test("infers original batch amount from current quantity and percentage", () => {
  assert.deepEqual(inferInitialQuantity(2, 50), {
    initialQuantity: 4, remainingPercentage: 50, source: "inferred",
  });
});

test("resets inconsistent old values and guards zero quantity", () => {
  assert.deepEqual(inferInitialQuantity(2, 0), {
    initialQuantity: 2, remainingPercentage: 100, source: "reset",
  });
  assert.deepEqual(inferInitialQuantity(0, 0), {
    initialQuantity: 1, remainingPercentage: 0, source: "reset",
  });
  assert.equal(inferInitialQuantity(-1, 50), null);
});
