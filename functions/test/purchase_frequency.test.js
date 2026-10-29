const assert = require("node:assert/strict");
const test = require("node:test");

const {
  buildShoppingSuggestions,
  MAX_SUGGESTIONS,
} = require("../lib/shopping/services/purchase_frequency.js");

// Noon in Vietnam (UTC+7) so calendar days are unambiguous.
function vnDay(day, month = 9) {
  return new Date(Date.UTC(2026, month - 1, day, 5, 0, 0));
}

function record(overrides) {
  return {
    key: "milk",
    name: "Sữa tươi",
    quantity: 2,
    unit: "hộp",
    categoryId: "dairy",
    foodId: "milk",
    purchaseDate: vnDay(1),
    status: "consumed",
    remainingPercentage: 0,
    ...overrides,
  };
}

const NOW = vnDay(23);

function milkHistory(extra = []) {
  return [
    record({purchaseDate: vnDay(1)}),
    record({purchaseDate: vnDay(8)}),
    record({purchaseDate: vnDay(15)}),
    ...extra,
  ];
}

test("suggests milk bought every 7 days that is out of stock", () => {
  const [suggestion] = buildShoppingSuggestions({
    now: NOW,
    records: milkHistory(),
    pendingKeys: new Set(),
  });

  assert.equal(suggestion.key, "milk");
  assert.equal(suggestion.avgIntervalDays, 7);
  assert.equal(suggestion.daysSinceLastPurchase, 8);
  assert.equal(suggestion.stockState, "out");
  assert.equal(suggestion.quantity, 2);
  assert.equal(suggestion.unit, "hộp");
  assert.equal(
    suggestion.reason,
    "Bạn thường mua Sữa tươi mỗi ~7 ngày, lần cuối 8 ngày trước, đã hết trong tủ."
  );
});

test("does not suggest when one batch still has 80% left", () => {
  const records = milkHistory();
  records[2] = record({
    purchaseDate: vnDay(15),
    status: "active",
    remainingPercentage: 80,
  });

  assert.deepEqual(
    buildShoppingSuggestions({now: NOW, records, pendingKeys: new Set()}),
    []
  );
});

test("marks low stock and keeps the reason wording", () => {
  const records = milkHistory();
  records[2] = record({
    purchaseDate: vnDay(15),
    status: "active",
    remainingPercentage: 10,
  });

  const [suggestion] = buildShoppingSuggestions({now: NOW, records, pendingKeys: new Set()});
  assert.equal(suggestion.stockState, "low");
  assert.match(suggestion.reason, /trong tủ còn ít\.$/);
});

test("needs at least three purchase days", () => {
  const records = [record({purchaseDate: vnDay(1)}), record({purchaseDate: vnDay(8)})];

  assert.deepEqual(
    buildShoppingSuggestions({now: NOW, records, pendingKeys: new Set()}),
    []
  );
});

test("counts several batches bought on the same day as one purchase", () => {
  const records = [
    record({purchaseDate: vnDay(1)}),
    record({purchaseDate: new Date(Date.UTC(2026, 8, 1, 1, 0, 0))}),
    record({purchaseDate: new Date(Date.UTC(2026, 8, 1, 14, 0, 0))}),
    record({purchaseDate: vnDay(8)}),
  ];

  assert.deepEqual(
    buildShoppingSuggestions({now: NOW, records, pendingKeys: new Set()}),
    []
  );
});

test("skips keys already pending in a shopping list", () => {
  assert.deepEqual(
    buildShoppingSuggestions({
      now: NOW,
      records: milkHistory(),
      pendingKeys: new Set(["milk"]),
    }),
    []
  );
});

test("one unusual 60-day gap does not skew the median interval", () => {
  const records = [
    record({purchaseDate: vnDay(1, 6)}),
    record({purchaseDate: vnDay(31, 7)}),
    record({purchaseDate: vnDay(7, 8)}),
    record({purchaseDate: vnDay(14, 8)}),
  ];

  const [suggestion] = buildShoppingSuggestions({
    now: vnDay(22, 8),
    records,
    pendingKeys: new Set(),
  });
  assert.equal(suggestion.avgIntervalDays, 7);
});

test("sorts by score and returns at most ten suggestions", () => {
  const records = [];
  for (let i = 0; i < 12; i++) {
    const key = `food-${i}`;
    // Larger i means a longer gap since the last purchase, hence a higher score.
    for (const day of [1, 4, 7]) {
      records.push(record({key, foodId: key, name: key, purchaseDate: vnDay(day)}));
    }
    records.push(record({key, foodId: key, name: key, purchaseDate: vnDay(10 - (i % 3))}));
  }

  const suggestions = buildShoppingSuggestions({now: NOW, records, pendingKeys: new Set()});
  assert.equal(suggestions.length, MAX_SUGGESTIONS);
  for (let i = 1; i < suggestions.length; i++) {
    assert.ok(suggestions[i - 1].score >= suggestions[i].score);
  }
});
