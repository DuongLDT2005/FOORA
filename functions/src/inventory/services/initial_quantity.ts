export interface InitialQuantityBackfill {
  initialQuantity: number;
  remainingPercentage: number;
  source: "inferred" | "reset";
}

export function inferInitialQuantity(
  quantity: unknown,
  percentage: unknown
): InitialQuantityBackfill | null {
  if (typeof quantity !== "number" || !Number.isFinite(quantity) || quantity < 0) {
    return null;
  }
  if (quantity === 0) {
    return {initialQuantity: 1, remainingPercentage: 0, source: "reset"};
  }
  if (typeof percentage === "number" && Number.isFinite(percentage) &&
      percentage > 0 && percentage <= 100) {
    const inferred = quantity / (percentage / 100);
    if (Number.isFinite(inferred) && inferred >= quantity) {
      const initialQuantity = Number(inferred.toFixed(6));
      return {
        initialQuantity,
        remainingPercentage: Math.round(quantity / initialQuantity * 100),
        source: "inferred",
      };
    }
  }
  return {initialQuantity: quantity, remainingPercentage: 100, source: "reset"};
}
