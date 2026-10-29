const assert = require("node:assert/strict");
const test = require("node:test");

const {
  calendarDateKey,
  calendarDaysUntil,
  planExpiryNotifications,
  selectNotificationsToCreate,
} = require("../lib/inventory/services/expiry_planner.js");

const NOW = new Date("2026-09-24T23:30:00.000Z");

function recipients(entries) {
  return new Map(entries.map(([uid, days]) => [uid, {expiryAlertDays: days}]));
}
const DEFAULT_RECIPIENTS = recipients([["user-1", [1, 3]], ["user-2", [1, 3]]]);

function item(overrides) {
  return {
    householdId: "home-1",
    inventoryItemId: "item-1",
    name: "Sữa tươi",
    status: "active",
    expirationDate: new Date("2026-09-27T10:00:00.000Z"),
    ...overrides,
  };
}

test("sends expired once and upcoming only on chosen days", () => {
  const planned = planExpiryNotifications({
    now: NOW,
    households: [{id: "home-1", memberIds: ["user-1"]}],
    recipients: recipients([["user-1", [1, 3]]]),
    items: [
      item({
        inventoryItemId: "expired-yesterday",
        expirationDate: new Date("2026-09-24T10:00:00.000Z"),
      }),
      item({
        inventoryItemId: "expired-earlier",
        expirationDate: new Date("2026-09-23T10:00:00.000Z"),
      }),
      item({
        inventoryItemId: "today",
        expirationDate: new Date("2026-09-25T16:00:00.000Z"),
      }),
      item({
        inventoryItemId: "tomorrow",
        expirationDate: new Date("2026-09-26T02:00:00.000Z"),
      }),
      item({
        inventoryItemId: "in-2-days",
        expirationDate: new Date("2026-09-27T02:00:00.000Z"),
      }),
      item({
        inventoryItemId: "in-3-days",
        expirationDate: new Date("2026-09-28T02:00:00.000Z"),
      }),
      item({
        inventoryItemId: "in-7-days",
        expirationDate: new Date("2026-10-02T02:00:00.000Z"),
      }),
    ],
  });

  const byItem = new Map(planned.map((entry) => [entry.inventoryItemId, entry]));
  assert.deepEqual(
    [...byItem.keys()].sort(),
    ["expired-yesterday", "in-3-days", "tomorrow"]
  );
  assert.equal(byItem.get("expired-yesterday").type, "expiration_alert");
  assert.equal(byItem.get("expired-yesterday").title, "Đã hết hạn");
  assert.equal(byItem.get("tomorrow").type, "upcoming_expiration");
  assert.equal(byItem.get("in-3-days").type, "upcoming_expiration");
  assert.equal(
    byItem.get("expired-yesterday").notificationId,
    "20260925_expiration_alert_expired-yesterday"
  );
});

test("uses each member's own expiryAlertDays", () => {
  const planned = planExpiryNotifications({
    now: NOW,
    households: [{id: "home-1", memberIds: ["user-1", "user-2", "user-3"]}],
    recipients: recipients([["user-1", [7]], ["user-2", [1, 3]]]),
    items: [item({expirationDate: new Date("2026-10-02T02:00:00.000Z")})],
  });

  assert.deepEqual(planned.map((entry) => entry.userId), ["user-1"]);
});

test("skips consumed and discarded items", () => {
  const planned = planExpiryNotifications({
    now: NOW,
    households: [{id: "home-1", memberIds: ["user-1"]}],
    recipients: DEFAULT_RECIPIENTS,
    items: [
      item({status: "consumed", inventoryItemId: "used"}),
      item({status: "discarded", inventoryItemId: "gone"}),
    ],
  });

  assert.deepEqual(planned, []);
});

test("fans out one document per household member with a stable daily id", () => {
  const input = {
    now: NOW,
    households: [{
      id: "home-1",
      memberIds: ["user-1", "user-2", "user-1", ""],
    }],
    recipients: DEFAULT_RECIPIENTS,
    items: [item({expirationDate: new Date("2026-09-26T02:00:00.000Z")})],
  };

  const first = planExpiryNotifications(input);
  const second = planExpiryNotifications(input);

  assert.equal(first.length, 2);
  assert.deepEqual(
    first.map((entry) => entry.userId).sort(),
    ["user-1", "user-2"]
  );
  assert.equal(first[0].notificationId, second[0].notificationId);
  assert.equal(first[0].isRead, false);
  assert.equal(
    calendarDateKey(NOW),
    "20260925"
  );
  assert.equal(
    calendarDaysUntil(new Date("2026-09-26T02:00:00.000Z"), NOW),
    1
  );
});

test("does not recreate an existing notification or reset isRead", () => {
  const planned = planExpiryNotifications({
    now: NOW,
    households: [{id: "home-1", memberIds: ["user-1", "user-2"]}],
    recipients: DEFAULT_RECIPIENTS,
    items: [item({expirationDate: new Date("2026-09-28T02:00:00.000Z")})],
  });
  const existing = planned[0];
  const stored = new Map([
    [`${existing.userId}/${existing.notificationId}`, {isRead: true}],
  ]);

  const toCreate = selectNotificationsToCreate(
    planned,
    new Set(stored.keys())
  );

  assert.equal(toCreate.length, 1);
  assert.equal(toCreate[0].userId, "user-2");
  assert.equal(stored.get(`${existing.userId}/${existing.notificationId}`).isRead, true);
  assert.equal(
    toCreate.some((entry) => entry.notificationId === existing.notificationId &&
      entry.userId === existing.userId),
    false
  );
});
