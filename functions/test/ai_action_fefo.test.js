const assert = require("node:assert/strict");
const test = require("node:test");

const {allocateFefo} = require("../lib/ai/services/ai_action_service.js");

test("allocates oldest expiration, then creation time, without clipping", () => {
  const candidates = [
    {itemId: "later", expirationDate: "2026-11-01", createdAtMillis: 1,
      quantity: 2},
    {itemId: "older", expirationDate: "2026-10-25", createdAtMillis: 2,
      quantity: 1},
    {itemId: "oldest", expirationDate: "2026-10-25", createdAtMillis: 1,
      quantity: 1},
  ];
  assert.deepEqual(allocateFefo(candidates, 3), [
    {itemId: "oldest", quantity: 1},
    {itemId: "older", quantity: 1},
    {itemId: "later", quantity: 1},
  ]);
  assert.equal(allocateFefo(candidates, 5), null);
});
