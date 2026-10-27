import {normalizeFoodName} from "../../utils/string";

/** Conservative category hints for food names not found in the food catalog. */
export function suggestFoodCategoryId(name: string): string | null {
  const lower = name.toLowerCase().trim();
  // Check accented words first for homonyms that collide when normalized (e.g. "bò" vs "bơ")
  if (/^(?:bò|thịt bò|bắp bò|gầu bò|nạm bò|sườn bò|thăn bò|đuôi bò)(?:\s|$)/iu.test(lower)) {
    return "meat";
  }
  if (/^(?:bơ|trái bơ|quả bơ)(?:\s|$)/iu.test(lower)) {
    return "fruits";
  }

  const text = normalizeFoodName(name);
  if (!text) return null;
  if (/^(rau|cai|bap cai|khoai|ca rot|ca chua|ca tim|nam|hanh|su hao|bi do)\b/
    .test(text)) return "vegetables";
  if (/^(cua|tom|ca|muc|oc|so|ngao|hau|ghe|hai san)\b/.test(text)) {
    return "seafood";
  }
  if (/^(thit|ga|vit|heo|lon|bo vien)\b/.test(text)) return "meat";
  if (/^(trung|sua|pho mai|bot sua|sua chua)\b/.test(text)) {
    return "dairy_eggs";
  }
  if (/^(gao|bun|mi|pho|banh mi|yen mach)\b/.test(text)) {
    return "grains_staples";
  }
  if (/^(tao|chuoi|cam|quyt|xoai|dua hau|nho|le)\b/.test(text)) {
    return "fruits";
  }
  return null;
}
