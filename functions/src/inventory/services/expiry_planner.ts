export const EXPIRY_TIME_ZONE = "Asia/Ho_Chi_Minh";
export const UPCOMING_EXPIRATION_MAX_DAYS = 3;

export type ExpiryNotificationType =
  | "expiration_alert"
  | "upcoming_expiration";

export interface ExpiryHousehold {
  id: string;
  memberIds: string[];
}

export interface ExpiryInventoryItem {
  householdId: string;
  inventoryItemId: string;
  name: string;
  status: string;
  expirationDate: Date;
}

export interface PlannedExpiryNotification {
  userId: string;
  notificationId: string;
  householdId: string;
  inventoryItemId: string;
  type: ExpiryNotificationType;
  title: string;
  message: string;
  isRead: false;
}

export interface PlanExpiryInput {
  now: Date;
  households: ExpiryHousehold[];
  items: ExpiryInventoryItem[];
  timeZone?: string;
}

export function calendarDateKey(
  date: Date,
  timeZone: string = EXPIRY_TIME_ZONE
): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  const day = parts.find((part) => part.type === "day")?.value;
  if (!year || !month || !day) {
    throw new Error("Unable to format calendar date.");
  }
  return `${year}${month}${day}`;
}

export function calendarDaysUntil(
  expirationDate: Date,
  now: Date,
  timeZone: string = EXPIRY_TIME_ZONE
): number {
  const expiration = dateKeyToUtcMidnight(
    calendarDateKey(expirationDate, timeZone)
  );
  const today = dateKeyToUtcMidnight(calendarDateKey(now, timeZone));
  return Math.round((expiration - today) / 86400000);
}

export function classifyExpiry(
  daysUntil: number
): ExpiryNotificationType | null {
  if (daysUntil < 0) {
    return "expiration_alert";
  }
  if (daysUntil <= UPCOMING_EXPIRATION_MAX_DAYS) {
    return "upcoming_expiration";
  }
  return null;
}

export function buildExpiryCopy(
  name: string,
  daysUntil: number
): {title: string; message: string} {
  const foodName = name.trim() || "Thực phẩm";
  if (daysUntil < 0) {
    const elapsed = Math.abs(daysUntil);
    return {
      title: "Đã hết hạn",
      message: elapsed === 1 ?
        `${foodName} đã hết hạn hôm qua.` :
        `${foodName} đã hết hạn ${elapsed} ngày.`,
    };
  }
  if (daysUntil === 0) {
    return {
      title: "Hết hạn hôm nay",
      message: `${foodName} hết hạn hôm nay.`,
    };
  }
  if (daysUntil === 1) {
    return {
      title: "Sắp hết hạn",
      message: `${foodName} sẽ hết hạn vào ngày mai.`,
    };
  }
  return {
    title: "Sắp hết hạn",
    message: `${foodName} sẽ hết hạn trong ${daysUntil} ngày.`,
  };
}

export function expiryNotificationId(
  dateKey: string,
  type: ExpiryNotificationType,
  inventoryItemId: string
): string {
  return `${dateKey}_${type}_${inventoryItemId}`;
}

export function planExpiryNotifications(
  input: PlanExpiryInput
): PlannedExpiryNotification[] {
  const timeZone = input.timeZone ?? EXPIRY_TIME_ZONE;
  const dateKey = calendarDateKey(input.now, timeZone);
  const membersByHousehold = new Map<string, string[]>();
  for (const household of input.households) {
    membersByHousehold.set(household.id, uniqueIds(household.memberIds));
  }

  const planned: PlannedExpiryNotification[] = [];
  const seen = new Set<string>();

  for (const item of input.items) {
    if (item.status !== "active" || !item.inventoryItemId) {
      continue;
    }
    const daysUntil = calendarDaysUntil(
      item.expirationDate,
      input.now,
      timeZone
    );
    const type = classifyExpiry(daysUntil);
    if (!type) {
      continue;
    }
    const members = membersByHousehold.get(item.householdId) ?? [];
    const copy = buildExpiryCopy(item.name, daysUntil);
    const notificationId = expiryNotificationId(
      dateKey,
      type,
      item.inventoryItemId
    );
    for (const userId of members) {
      const key = `${userId}/${notificationId}`;
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);
      planned.push({
        userId,
        notificationId,
        householdId: item.householdId,
        inventoryItemId: item.inventoryItemId,
        type,
        title: copy.title,
        message: copy.message,
        isRead: false,
      });
    }
  }

  return planned;
}

export function selectNotificationsToCreate(
  planned: PlannedExpiryNotification[],
  existingKeys: ReadonlySet<string>
): PlannedExpiryNotification[] {
  return planned.filter((item) => {
    return !existingKeys.has(`${item.userId}/${item.notificationId}`);
  });
}

function dateKeyToUtcMidnight(dateKey: string): number {
  const year = Number(dateKey.slice(0, 4));
  const month = Number(dateKey.slice(4, 6));
  const day = Number(dateKey.slice(6, 8));
  return Date.UTC(year, month - 1, day);
}

function uniqueIds(ids: string[]): string[] {
  const unique = new Set<string>();
  for (const id of ids) {
    if (id.trim()) {
      unique.add(id);
    }
  }
  return [...unique];
}
