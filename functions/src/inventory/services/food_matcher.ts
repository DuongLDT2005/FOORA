import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {normalizeFoodName} from "../../utils/string";

/** Active entry of the `foods` catalog, prepared for name matching. */
export interface MasterFoodItem {
  id: string;
  name: string;
  normalizedName: string;
  aliases: string[];
  categoryId: string;
  defaultUnit: string;
  photoUrl?: string | null;
}

export interface MasterFoodMatch {
  matchedFood: MasterFoodItem | null;
  matchScore: number;
}

/** The catalog changes rarely; one read per warm instance is enough. */
const CATALOG_TTL_MS = 10 * 60 * 1000;
let cachedCatalog: {foods: MasterFoodItem[]; loadedAt: number} | null = null;

/**
 * Maps a `foods` document to a matcher entry. Aliases are stored with or
 * without accents, so both they and the name are normalized the same way
 * as the text being matched.
 * @param {string} id Document id.
 * @param {FirebaseFirestore.DocumentData} data Document data.
 * @return {MasterFoodItem} Matcher entry.
 */
export function toMasterFoodItem(
  id: string,
  data: FirebaseFirestore.DocumentData
): MasterFoodItem {
  return {
    id,
    name: data.name as string,
    normalizedName: normalizeFoodName(data.normalizedName || data.name || ""),
    aliases: [...new Set(((data.aliases || []) as string[])
      .map((alias) => normalizeFoodName(alias))
      .filter((alias) => alias.length > 0))],
    categoryId: data.categoryId as string,
    defaultUnit: data.defaultUnit as string,
    photoUrl: (data.photoUrl as string) || null,
  };
}

/**
 * Loads the active food catalog, cached per instance for ten minutes.
 * @return {Promise<MasterFoodItem[]>} Active catalog entries.
 */
export async function loadMasterFoods(): Promise<MasterFoodItem[]> {
  if (cachedCatalog && Date.now() - cachedCatalog.loadedAt < CATALOG_TTL_MS) {
    return cachedCatalog.foods;
  }
  const snap = await db.collection(Collections.FOODS)
    .where("isActive", "==", true).get();
  const foods = snap.docs.map((doc) => toMasterFoodItem(doc.id, doc.data()));
  cachedCatalog = {foods, loadedAt: Date.now()};
  return foods;
}

/**
 * Scoring-based Master Food Matching:
 * 1. Exact normalized name match -> 1.0
 * 2. Exact alias match -> 0.95
 * 3. Whole phrase containment with specificity check -> 0.82 - 0.92
 * 4. Specificity penalty: If product has distinguishing modifiers (e.g. 'thanh trùng', 'chua', 'bột')
 *    and candidate master food is just generic (e.g. 'sữa'), deduct score so it won't false match.
 *
 * Minimum threshold to accept match is 0.80.
 * Shared by receipt scanning and the assistant's inventory entry.
 * @param {string} normRawName Name normalized with `normalizeFoodName`.
 * @param {MasterFoodItem[]} masterFoods Catalog entries.
 * @return {MasterFoodMatch} Best match, or null below the threshold.
 */
export function findBestMasterFoodMatch(
  normRawName: string,
  masterFoods: MasterFoodItem[]
): MasterFoodMatch {
  let bestFood: MasterFoodItem | null = null;
  let bestScore = 0;

  const normTokens = normRawName.split(" ").filter((t) => t.length > 0);
  const paddedNorm = ` ${normRawName} `;

  for (const food of masterFoods) {
    let score = 0;

    // Rule 1: Exact normalized name match
    if (normRawName === food.normalizedName) {
      score = 1.0;
    } else if (food.aliases.includes(normRawName)) {
      // Rule 2: Exact alias match
      score = 0.95;
    } else {
      // Rule 3: Whole phrase / token boundary containment
      const paddedFood = ` ${food.normalizedName} `;
      const foodTokens = food.normalizedName.split(" ").filter((t) => t.length > 0);

      let aliasPhraseScore = 0;
      for (const alias of food.aliases) {
        if (alias.length >= 4 && paddedNorm.includes(` ${alias} `)) {
          const aliasTokens = alias.split(" ").filter((t) => t.length > 0);
          const specificity = aliasTokens.length / normTokens.length;
          const aScore = 0.82 + Math.min(0.12, specificity * 0.12);
          if (aScore > aliasPhraseScore) aliasPhraseScore = aScore;
        }
      }

      if (paddedNorm.includes(paddedFood) && food.normalizedName.length >= 3) {
        const specificity = foodTokens.length / normTokens.length;
        let containmentScore = 0.84 + Math.min(0.12, specificity * 0.12);

        // Specificity penalty: Prevent "Mộc Châu Sữa thanh trùng" matching generic "Sữa"
        const distinguishingKeywords = [
          "thanh trung",
          "tiet trung",
          "chua",
          "dac",
          "bot",
          "chay",
          "dam",
          "tron",
        ];
        const rawHasDiff = distinguishingKeywords.some((kw) => normRawName.includes(kw));
        const foodHasDiff = distinguishingKeywords.some((kw) => food.normalizedName.includes(kw));

        if (rawHasDiff && !foodHasDiff) {
          containmentScore -= 0.18; // Penalty drops score below 0.80 threshold
        }

        score = Math.max(aliasPhraseScore, containmentScore);
      } else if (aliasPhraseScore > 0) {
        score = aliasPhraseScore;
      }
    }

    if (score > bestScore) {
      bestScore = score;
      bestFood = food;
    }
  }

  // Only accept match if score meets or exceeds 0.80 threshold
  if (bestScore >= 0.8) {
    return {matchedFood: bestFood, matchScore: bestScore};
  }

  return {matchedFood: null, matchScore: 0};
}
