/**
 * Pure copy builder for the weekly "time to go shopping" reminder (PLAN_02 §3.3).
 */

export const SHOPPING_REMINDER_TITLE = "Đến giờ đi chợ rồi! 🛒";
export const SHOPPING_REMINDER_TYPE = "shopping_reminder";
const MAX_NAMES = 3;

export interface ShoppingReminderInput {
  /** Names of every pending item, oldest first. */
  pendingNames: string[];
  /** Names of "frequently bought" suggestions, best first. */
  suggestionNames: string[];
}

export interface PlannedShoppingReminder {
  title: string;
  message: string;
}

/**
 * Returns null when there is nothing to remind about.
 */
export function planShoppingReminder(
  input: ShoppingReminderInput
): PlannedShoppingReminder | null {
  const pending = input.pendingNames.filter((n) => n.trim());
  const suggestions = input.suggestionNames.filter((n) => n.trim());
  if (pending.length === 0 && suggestions.length === 0) {
    return null;
  }

  const sentences: string[] = [];
  if (pending.length > 0) {
    sentences.push(`Danh sách có ${pending.length} món (${joinNames(pending)}).`);
    if (suggestions.length > 0) {
      sentences.push(`Gợi ý thêm: ${joinNames(suggestions)}.`);
    }
  } else {
    sentences.push(`Gợi ý nên mua: ${joinNames(suggestions)}.`);
  }

  return {title: SHOPPING_REMINDER_TITLE, message: sentences.join(" ")};
}

export function shoppingReminderId(isoWeekKey: string): string {
  return `shopping_${isoWeekKey}`;
}

function joinNames(names: string[]): string {
  const shown = names.slice(0, MAX_NAMES).map((n) => n.trim()).join(", ");
  return names.length > MAX_NAMES ? `${shown}…` : shown;
}
