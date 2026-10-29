/**
 * Pure "frequently bought" suggestion algorithm (PLAN_01 §4.1).
 * No Firebase imports so it can be unit-tested with `node --test`.
 */
import {calendarDateKey, EXPIRY_TIME_ZONE} from "../../inventory/services/expiry_planner";

export const LOOKBACK_DAYS = 180;
export const MIN_PURCHASE_DAYS = 3;
export const DUE_RATIO = 0.8;
export const LOW_STOCK_RATIO = 0.25;
export const MAX_SUGGESTIONS = 10;

export type PurchaseStatus = "active" | "consumed" | "discarded";
export type StockState = "out" | "low";

export interface PurchaseRecord {
  key: string;
  name: string;
  quantity: number;
  unit: string;
  categoryId: string;
  foodId: string | null;
  purchaseDate: Date;
  status: PurchaseStatus;
  remainingPercentage: number;
}

export interface SuggestionInput {
  now: Date;
  records: PurchaseRecord[];
  pendingKeys: ReadonlySet<string>;
  timeZone?: string;
}

export interface ShoppingSuggestion {
  key: string;
  name: string;
  foodId: string | null;
  categoryId: string;
  quantity: number;
  unit: string;
  avgIntervalDays: number;
  daysSinceLastPurchase: number;
  purchaseCount: number;
  stockState: StockState;
  score: number;
  reason: string;
}

/**
 * Key used to group purchases of the same food: master food id when known,
 * otherwise the normalized name.
 */
export function purchaseKey(foodId: unknown, normalizedName: unknown): string {
  if (typeof foodId === "string" && foodId.trim()) {
    return foodId.trim();
  }
  return typeof normalizedName === "string" ? normalizedName.trim() : "";
}

export function buildShoppingSuggestions(
  input: SuggestionInput
): ShoppingSuggestion[] {
  const timeZone = input.timeZone ?? EXPIRY_TIME_ZONE;
  const todayKey = calendarDateKey(input.now, timeZone);

  const byKey = new Map<string, PurchaseRecord[]>();
  for (const record of input.records) {
    if (!record.key) continue;
    const group = byKey.get(record.key);
    if (group) {
      group.push(record);
    } else {
      byKey.set(record.key, [record]);
    }
  }

  const suggestions: ShoppingSuggestion[] = [];
  for (const [key, records] of byKey) {
    if (input.pendingKeys.has(key)) continue;

    // Several batches bought on the same calendar day count as one purchase.
    const dayKeys = [...new Set(
      records.map((r) => calendarDateKey(r.purchaseDate, timeZone))
    )].sort();
    if (dayKeys.length < MIN_PURCHASE_DAYS) continue;

    const intervals: number[] = [];
    for (let i = 1; i < dayKeys.length; i++) {
      intervals.push(daysBetween(dayKeys[i - 1], dayKeys[i]));
    }
    const avgIntervalDays = Math.max(1, median(intervals));
    const daysSince = daysBetween(dayKeys[dayKeys.length - 1], todayKey);

    const active = records.filter((r) => r.status === "active");
    const stockLevel = active.reduce(
      (sum, r) => sum + clampPercentage(r.remainingPercentage) / 100,
      0
    );
    let stockState: StockState | "ok";
    if (active.length === 0 || stockLevel === 0) {
      stockState = "out";
    } else if (stockLevel < LOW_STOCK_RATIO) {
      stockState = "low";
    } else {
      stockState = "ok";
    }

    if (daysSince < DUE_RATIO * avgIntervalDays || stockState === "ok") {
      continue;
    }

    const score = (daysSince / avgIntervalDays) *
      (stockState === "out" ? 1 : 0.6) *
      Math.log2(1 + dayKeys.length);

    const latest = records.reduce((a, b) =>
      b.purchaseDate.getTime() > a.purchaseDate.getTime() ? b : a
    );
    const roundedInterval = Math.round(avgIntervalDays);
    const stockText = stockState === "out" ? "đã hết trong tủ" : "trong tủ còn ít";

    suggestions.push({
      key,
      name: latest.name,
      foodId: latest.foodId,
      categoryId: latest.categoryId,
      quantity: median(records.map((r) => r.quantity)),
      unit: mostFrequent(records.map((r) => r.unit)),
      avgIntervalDays,
      daysSinceLastPurchase: daysSince,
      purchaseCount: dayKeys.length,
      stockState,
      score,
      reason: `Bạn thường mua ${latest.name} mỗi ~${roundedInterval} ngày, ` +
        `lần cuối ${daysSince} ngày trước, ${stockText}.`,
    });
  }

  return suggestions
    .sort((a, b) => b.score - a.score)
    .slice(0, MAX_SUGGESTIONS);
}

function daysBetween(fromKey: string, toKey: string): number {
  return Math.round((keyToUtc(toKey) - keyToUtc(fromKey)) / 86400000);
}

function keyToUtc(key: string): number {
  return Date.UTC(
    Number(key.slice(0, 4)),
    Number(key.slice(4, 6)) - 1,
    Number(key.slice(6, 8))
  );
}

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ?
    (sorted[mid - 1] + sorted[mid]) / 2 :
    sorted[mid];
}

function mostFrequent(values: string[]): string {
  const counts = new Map<string, number>();
  let best = values[0] ?? "";
  let bestCount = 0;
  for (const value of values) {
    const count = (counts.get(value) ?? 0) + 1;
    counts.set(value, count);
    if (count > bestCount) {
      best = value;
      bestCount = count;
    }
  }
  return best;
}

function clampPercentage(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.min(100, Math.max(0, value));
}
