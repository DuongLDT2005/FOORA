const assert = require("node:assert/strict");
const test = require("node:test");

const {
  planShoppingReminder,
  shoppingReminderId,
  SHOPPING_REMINDER_TITLE,
} = require("../lib/notification/services/reminder_planner.js");

test("lists pending items and suggestions", () => {
  const reminder = planShoppingReminder({
    pendingNames: ["Sữa tươi", "Trứng gà", "Cà chua", "Hành lá"],
    suggestionNames: ["Thịt heo"],
  });

  assert.equal(reminder.title, SHOPPING_REMINDER_TITLE);
  assert.equal(
    reminder.message,
    "Danh sách có 4 món (Sữa tươi, Trứng gà, Cà chua…). Gợi ý thêm: Thịt heo."
  );
});

test("does not add an ellipsis for three names or fewer", () => {
  const reminder = planShoppingReminder({
    pendingNames: ["Sữa tươi", "Trứng gà", "Cà chua"],
    suggestionNames: [],
  });

  assert.equal(reminder.message, "Danh sách có 3 món (Sữa tươi, Trứng gà, Cà chua).");
});

test("falls back to suggestions when the list is empty", () => {
  const reminder = planShoppingReminder({
    pendingNames: [],
    suggestionNames: ["Thịt heo", "Rau muống"],
  });

  assert.equal(reminder.message, "Gợi ý nên mua: Thịt heo, Rau muống.");
});

test("returns null when there is nothing to remind", () => {
  assert.equal(planShoppingReminder({pendingNames: [], suggestionNames: [" "]}), null);
});

test("uses a stable weekly id", () => {
  assert.equal(shoppingReminderId("2026W42"), "shopping_2026W42");
});
