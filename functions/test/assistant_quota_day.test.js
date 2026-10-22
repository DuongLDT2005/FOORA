const assert = require("node:assert/strict");
const test = require("node:test");

const {
  assistantQuotaDay,
} = require("../lib/ai/services/ai_assistant_service.js");

test("uses Vietnam day boundaries for assistant quota", () => {
  assert.equal(assistantQuotaDay(new Date("2026-10-22T16:59:59Z")), "2026-10-22");
  assert.equal(assistantQuotaDay(new Date("2026-10-22T17:00:00Z")), "2026-10-23");
});
