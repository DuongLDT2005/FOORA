const assert = require("node:assert/strict");
const test = require("node:test");

const {
  DEFAULT_SETTINGS,
  parseSettings,
  vnClock,
} = require("../lib/notification/services/notification_settings.js");

test("missing settings fall back to defaults", () => {
  assert.deepEqual(parseSettings(undefined), {...DEFAULT_SETTINGS});
  assert.deepEqual(parseSettings(null), {...DEFAULT_SETTINGS});
  assert.deepEqual(DEFAULT_SETTINGS.expiryAlertDays, [1, 3]);
  assert.equal(DEFAULT_SETTINGS.shoppingReminderWeekday, 6);
});

test("invalid fields fall back one by one", () => {
  const parsed = parseSettings({
    pushEnabled: false,
    expiryAlertDays: [7, 2, 1, 7, "3"],
    reminderHour: 24,
    shoppingReminderEnabled: "yes",
    shoppingReminderWeekday: 0,
  });

  assert.equal(parsed.pushEnabled, false);
  assert.deepEqual(parsed.expiryAlertDays, [1, 7]);
  assert.equal(parsed.reminderHour, DEFAULT_SETTINGS.reminderHour);
  assert.equal(parsed.shoppingReminderEnabled, true);
  assert.equal(parsed.shoppingReminderWeekday, 6);
});

test("keeps an empty alert list (user turned all alerts off)", () => {
  assert.deepEqual(parseSettings({expiryAlertDays: []}).expiryAlertDays, []);
});

test("vnClock converts UTC to Vietnam time across the day boundary", () => {
  // Sunday 2026-10-25 23:59 UTC = Monday 2026-10-26 06:59 in Vietnam.
  const clock = vnClock(new Date("2026-10-25T23:59:00.000Z"));
  assert.equal(clock.isoWeekday, 1);
  assert.equal(clock.hour, 6);
  assert.equal(clock.isoWeekKey, "2026W44");

  const before = vnClock(new Date("2026-10-25T16:59:00.000Z"));
  assert.equal(before.isoWeekday, 7);
  assert.equal(before.hour, 23);
  assert.equal(before.isoWeekKey, "2026W43");
});

test("vnClock uses the ISO week-year around new year", () => {
  // 2027-01-01 is a Friday and belongs to ISO week 53 of 2026.
  assert.equal(vnClock(new Date("2027-01-01T05:00:00.000Z")).isoWeekKey, "2026W53");
  // 2025-12-29 is a Monday and starts ISO week 1 of 2026.
  assert.equal(vnClock(new Date("2025-12-29T05:00:00.000Z")).isoWeekKey, "2026W01");
});
