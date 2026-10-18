const assert = require("node:assert/strict");
const test = require("node:test");

const {
  MembershipIds,
  pickActiveSubscription,
  resolveMembershipId,
} = require("../lib/membership/services/entitlement.js");

const NOW = Date.parse("2026-10-18T00:00:00.000Z");
const DAY = 24 * 60 * 60 * 1000;
const ts = (millis) => ({toMillis: () => millis});

function sub(overrides) {
  return {
    membershipId: MembershipIds.PREMIUM,
    status: "active",
    startDate: ts(NOW - DAY),
    endDate: ts(NOW + 10 * DAY),
    ...overrides,
  };
}

test("falls back to free without subscriptions", () => {
  assert.equal(resolveMembershipId([], NOW), MembershipIds.FREE);
});

test("active subscription inside its window grants the plan", () => {
  assert.equal(resolveMembershipId([sub({})], NOW), MembershipIds.PREMIUM);
});

test("ignores expired, cancelled, ended and not-yet-started subscriptions", () => {
  const candidates = [
    sub({status: "expired"}),
    sub({status: "cancelled"}),
    sub({endDate: ts(NOW)}),
    sub({startDate: ts(NOW + DAY)}),
    sub({endDate: undefined}),
  ];
  assert.equal(resolveMembershipId(candidates, NOW), MembershipIds.FREE);
});

test("picks the subscription with the furthest endDate", () => {
  const short = sub({endDate: ts(NOW + DAY), lastPaymentId: "a"});
  const long = sub({endDate: ts(NOW + 30 * DAY), lastPaymentId: "b"});
  assert.equal(pickActiveSubscription([short, long], NOW).lastPaymentId, "b");
});

test("accepts JS Date values", () => {
  const candidate = sub({
    startDate: new Date(NOW - DAY),
    endDate: new Date(NOW + DAY),
  });
  assert.equal(resolveMembershipId([candidate], NOW), MembershipIds.PREMIUM);
});
