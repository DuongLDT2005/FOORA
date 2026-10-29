/**
 * Pure helpers for `users/{uid}.notificationSettings` (PLAN_02 §3.2).
 */
import {EXPIRY_TIME_ZONE} from "../../inventory/services/expiry_planner";

export const EXPIRY_ALERT_DAY_OPTIONS = [1, 3, 7] as const;

export interface NotificationSettings {
  pushEnabled: boolean;
  expiryAlertDays: number[];
  reminderHour: number;
  shoppingReminderEnabled: boolean;
  shoppingReminderWeekday: number;
}

export const DEFAULT_SETTINGS: Readonly<NotificationSettings> = Object.freeze({
  pushEnabled: true,
  expiryAlertDays: [1, 3],
  reminderHour: 8,
  shoppingReminderEnabled: true,
  shoppingReminderWeekday: 6,
});

/**
 * Parses a stored settings map. Each invalid or missing field falls back to
 * its default independently.
 */
export function parseSettings(raw: unknown): NotificationSettings {
  const data = raw && typeof raw === "object" ? raw as Record<string, unknown> : {};
  return {
    pushEnabled: typeof data.pushEnabled === "boolean" ?
      data.pushEnabled :
      DEFAULT_SETTINGS.pushEnabled,
    expiryAlertDays: parseAlertDays(data.expiryAlertDays),
    reminderHour: isIntInRange(data.reminderHour, 0, 23) ?
      data.reminderHour as number :
      DEFAULT_SETTINGS.reminderHour,
    shoppingReminderEnabled: typeof data.shoppingReminderEnabled === "boolean" ?
      data.shoppingReminderEnabled :
      DEFAULT_SETTINGS.shoppingReminderEnabled,
    shoppingReminderWeekday: isIntInRange(data.shoppingReminderWeekday, 1, 7) ?
      data.shoppingReminderWeekday as number :
      DEFAULT_SETTINGS.shoppingReminderWeekday,
  };
}

export interface VnClock {
  /** 1 = Monday ... 7 = Sunday. */
  isoWeekday: number;
  hour: number;
  /** ISO week of the Vietnam calendar date, e.g. `2026W42`. */
  isoWeekKey: string;
}

export function vnClock(now: Date, timeZone: string = EXPIRY_TIME_ZONE): VnClock {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    hourCycle: "h23",
  }).formatToParts(now);
  const part = (type: string) => Number(parts.find((p) => p.type === type)?.value);

  const date = new Date(Date.UTC(part("year"), part("month") - 1, part("day")));
  const isoWeekday = ((date.getUTCDay() + 6) % 7) + 1;

  // The ISO week belongs to the year of its Thursday.
  const thursday = new Date(date.getTime() + (4 - isoWeekday) * 86400000);
  const weekYear = thursday.getUTCFullYear();
  const yearStart = Date.UTC(weekYear, 0, 1);
  const week = Math.ceil(((thursday.getTime() - yearStart) / 86400000 + 1) / 7);

  return {
    isoWeekday,
    hour: part("hour"),
    isoWeekKey: `${weekYear}W${String(week).padStart(2, "0")}`,
  };
}

function parseAlertDays(value: unknown): number[] {
  if (!Array.isArray(value)) {
    return [...DEFAULT_SETTINGS.expiryAlertDays];
  }
  const allowed = new Set<number>(EXPIRY_ALERT_DAY_OPTIONS);
  return [...new Set(value.filter((d): d is number => allowed.has(d as number)))]
    .sort((a, b) => a - b);
}

function isIntInRange(value: unknown, min: number, max: number): boolean {
  return Number.isInteger(value) && (value as number) >= min && (value as number) <= max;
}
