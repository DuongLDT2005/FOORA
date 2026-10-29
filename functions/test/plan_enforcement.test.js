const assert = require("node:assert/strict");
const test = require("node:test");

const {
  pickLockedItemIds,
  pickLockedMembers,
} = require("../lib/membership/services/entitlement.js");
const {
  premiumReminderStage,
} = require("../lib/membership/services/premium_reminder.js");

const DAY = 86400000;

test("keeps the owner and the earliest members within the seat limit", () => {
  assert.deepEqual(
    pickLockedMembers(["a", "owner", "b", "c", "d"], "owner", 3),
    ["c", "d"]
  );
});

test("never locks the owner even when listed last", () => {
  assert.deepEqual(
    pickLockedMembers(["a", "b", "c", "owner"], "owner", 2),
    ["b", "c"]
  );
});

test("locks nobody when the household fits", () => {
  assert.deepEqual(pickLockedMembers(["owner", "a"], "owner", 3), []);
});

test("locks the most recently added items over the food limit", () => {
  const items = [
    {id: "new", createdAtMillis: 300},
    {id: "old", createdAtMillis: 100},
    {id: "mid", createdAtMillis: 200},
  ];
  assert.deepEqual(pickLockedItemIds(items, 2), ["new"]);
  assert.deepEqual(pickLockedItemIds(items, 0), ["old", "mid", "new"]);
});

test("unlimited plans lock no items", () => {
  assert.deepEqual(pickLockedItemIds([{id: "a", createdAtMillis: 1}], null), []);
});

test("schedules the 3-day and final-day Premium reminders", () => {
  const now = 1_000_000_000_000;
  assert.equal(premiumReminderStage(now + 4 * DAY, now), null);
  assert.equal(premiumReminderStage(now + 3 * DAY, now), "3d");
  assert.equal(premiumReminderStage(now + 2 * DAY, now), "3d");
  assert.equal(premiumReminderStage(now + DAY, now), "1d");
  assert.equal(premiumReminderStage(now + 60000, now), "1d");
  assert.equal(premiumReminderStage(now, now), null);
});
