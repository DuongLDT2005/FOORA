const assert = require("node:assert/strict");
const test = require("node:test");

const {
  calendarDateKey,
  calendarDaysUntil,
  planExpiryNotifications,
  selectNotificationsToCreate,
} = require("../lib/inventory/services/expiry_planner.js");

const NOW = new Date("2026-09-24T23:30:00.000Z");

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

test("classifies active items inside the documented expiry window", () => {
  const planned = planExpiryNotifications({
    now: NOW,
    households: [{id: "home-1", memberIds: ["user-1"]}],
    items: [
      item({
        inventoryItemId: "expired",
        expirationDate: new Date("2026-09-23T10:00:00.000Z"),
      }),
      item({
        inventoryItemId: "today",
        name: "Trứng",
        expirationDate: new Date("2026-09-25T16:00:00.000Z"),
      }),
      item({
        inventoryItemId: "soon",
        expirationDate: new Date("2026-09-28T02:00:00.000Z"),
      }),
      item({
        inventoryItemId: "fresh",
        expirationDate: new Date("2026-10-02T02:00:00.000Z"),
      }),
    ],
  });

  const byItem = new Map(planned.map((entry) => [entry.inventoryItemId, entry]));
  assert.equal(byItem.get("expired").type, "expiration_alert");
  assert.equal(byItem.get("expired").title, "Đã hết hạn");
  assert.equal(byItem.get("today").type, "upcoming_expiration");
  assert.match(byItem.get("today").message, /hết hạn hôm nay/);
  assert.equal(byItem.get("soon").type, "upcoming_expiration");
  assert.equal(byItem.has("fresh"), false);
  assert.equal(
    byItem.get("expired").notificationId,
    "20260925_expiration_alert_expired"
  );
});

test("skips consumed and discarded items", () => {
  const planned = planExpiryNotifications({
    now: NOW,
    households: [{id: "home-1", memberIds: ["user-1"]}],
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
    items: [item()],
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
