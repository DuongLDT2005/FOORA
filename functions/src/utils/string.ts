/**
 * Normalizes Vietnamese and arbitrary text to lowercase unaccented string.
 * Used for searchable fields like `normalizedName` in foods and inventory_items.
 * Example: "Thịt ba chỉ heo" -> "thit ba chi heo"
 */
export function normalizeFoodName(name: string): string {
  if (!name) return "";

  return name
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "") // Remove combining diacritical marks
    .replace(/đ/g, "d")
    .replace(/Đ/g, "d")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ") // Replace non-alphanumeric chars with space
    .replace(/\s+/g, " ") // Collapse multiple spaces
    .trim();
}
