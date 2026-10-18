/**
 * Pure entitlement rules shared by every module (no Firebase imports, so the
 * logic is unit-testable). Source of truth per docs/DATABASE.md §16 and
 * docs/PAYMENT_END_TO_END_PLAN.md: an active subscription grants the plan,
 * `users.membershipId` is only a derived cache.
 */

export const MembershipIds = {
  FREE: "free",
  PREMIUM: "premium",
} as const;

/** Anything with Firestore Timestamp's `toMillis()` (or a JS Date). */
export type TimeLike = {toMillis(): number} | Date | null | undefined;

export interface SubscriptionLike {
  membershipId?: unknown;
  status?: unknown;
  startDate?: TimeLike;
  endDate?: TimeLike;
}

/**
 * Converts a Timestamp/Date to epoch millis, or `null` when missing.
 * @param {TimeLike} value Timestamp-like value.
 * @return {number | null} Epoch millis.
 */
export function toMillis(value: TimeLike): number | null {
  if (value === null || value === undefined) return null;
  if (value instanceof Date) return value.getTime();
  return typeof value.toMillis === "function" ? value.toMillis() : null;
}

/**
 * Returns the subscription that currently grants entitlement:
 * `status == "active"`, `startDate <= now < endDate`; when several match,
 * the one with the furthest `endDate` wins.
 * @param {SubscriptionLike[]} subscriptions Candidate subscriptions.
 * @param {number} nowMillis Current server time in millis.
 * @return {SubscriptionLike | null} The entitling subscription.
 */
export function pickActiveSubscription<T extends SubscriptionLike>(
  subscriptions: T[],
  nowMillis: number
): T | null {
  let best: T | null = null;
  let bestEnd = -Infinity;
  for (const subscription of subscriptions) {
    if (subscription.status !== "active") continue;
    if (typeof subscription.membershipId !== "string") continue;
    const start = toMillis(subscription.startDate);
    const end = toMillis(subscription.endDate);
    if (end === null || end <= nowMillis) continue;
    if (start !== null && start > nowMillis) continue;
    if (end > bestEnd) {
      best = subscription;
      bestEnd = end;
    }
  }
  return best;
}

/**
 * Membership id granted by [subscriptions], falling back to the Free plan.
 * @param {SubscriptionLike[]} subscriptions Candidate subscriptions.
 * @param {number} nowMillis Current server time in millis.
 * @return {string} Effective membership id.
 */
export function resolveMembershipId(
  subscriptions: SubscriptionLike[],
  nowMillis: number
): string {
  const active = pickActiveSubscription(subscriptions, nowMillis);
  return active ? String(active.membershipId) : MembershipIds.FREE;
}
