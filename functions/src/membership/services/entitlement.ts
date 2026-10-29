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

/**
 * Hard ceiling on members per household, applied even when a plan's
 * `memberLimit` is null (unlimited) or misconfigured, to prevent abuse.
 */
export const MAX_HOUSEHOLD_MEMBERS = 20;

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
 * Members who exceed the household's seat limit. The owner always keeps a
 * seat; the remaining seats go to members in join order (the `members`
 * array keeps arrayUnion insertion order).
 * @param {string[]} members Member uids in join order.
 * @param {string} ownerId Household owner uid.
 * @param {number} seatLimit Seats allowed, owner included.
 * @return {string[]} Uids to lock, in join order.
 */
export function pickLockedMembers(
  members: string[],
  ownerId: string,
  seatLimit: number
): string[] {
  const kept = new Set<string>([ownerId]);
  for (const uid of members) {
    if (kept.size >= seatLimit) break;
    kept.add(uid);
  }
  return members.filter((uid) => !kept.has(uid));
}

/**
 * Active items that exceed the food limit: the earliest added stay usable,
 * later ones are locked. `null` means unlimited.
 * @param {{id: string, createdAtMillis: number}[]} items Active items.
 * @param {number | null} foodLimit Plan food limit.
 * @return {string[]} Item ids to lock.
 */
export function pickLockedItemIds(
  items: {id: string; createdAtMillis: number}[],
  foodLimit: number | null
): string[] {
  if (foodLimit === null) return [];
  return [...items]
    .sort((a, b) =>
      a.createdAtMillis - b.createdAtMillis || a.id.localeCompare(b.id))
    .slice(Math.max(foodLimit, 0))
    .map((item) => item.id);
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
