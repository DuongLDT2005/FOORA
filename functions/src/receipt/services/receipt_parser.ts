import {GoogleGenAI, Type} from "@google/genai";
import * as logger from "firebase-functions/logger";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {normalizeFoodName} from "../../utils/string";
import {InventoryService} from "../../inventory/services/inventory_service";

/**
 * Raw receipt item extracted purely from the receipt by Gemini or fallback parser.
 * Notice: Does NOT contain foodId, categoryId, storageLocationId, or expirationDate.
 */
export interface ParsedReceiptItemRaw {
  rawName: string;
  purchaseQuantity: number;
  purchaseUnit: string;
  productSize?: number;
  productSizeUnit?: string;
  packCount?: number;
  packUnit?: string;
}

export interface MasterFoodItem {
  id: string;
  name: string;
  normalizedName: string;
  aliases: string[];
  categoryId: string;
  defaultUnit: string;
}

export interface MatchedExistingStock {
  itemId: string;
  name: string;
  quantity: number;
  unit: string;
  storageLocationName: string;
  expirationDate: string;
  daysRemaining: number;
}

export interface EnrichedParsedItem {
  rawName: string;
  name: string;
  normalizedName: string;
  foodId: string | null;
  categoryId: string;
  quantity: number;
  unit: string;
  storageLocationId: string;
  estimatedExpirationDate: string;
  confidence: number;
  matchedExistingItem: MatchedExistingStock | null;
}

export class ReceiptParserService {
  /**
   * Parses receipt using multimodal Gemini (Image + OCR text),
   * validates raw extractions, performs scoring-based master food matching,
   * computes final quantities, categories, storage locations, and checks inventory duplicates.
   */
  static async parseAndEnrich(
    ocrText: string,
    householdId: string,
    imageBase64?: string,
    mimeType?: string
  ): Promise<EnrichedParsedItem[]> {
    // 1. Fetch available categories, master foods, and existing household items
    const [categoriesSnap, masterFoodsSnap, activeItemsSnap] = await Promise.all([
      db.collection(Collections.FOOD_CATEGORIES).get(),
      db.collection(Collections.FOODS).where("isActive", "==", true).get(),
      db.collection(Collections.HOUSEHOLDS)
        .doc(householdId)
        .collection(Collections.INVENTORY_ITEMS)
        .where("status", "==", "active")
        .get(),
    ]);

    const categories = categoriesSnap.docs.map((d) => ({
      id: d.id,
      name: d.data().name as string,
      defaultShelfLife: d.data().defaultShelfLife as Record<
        string,
        {maxValue?: number; unit?: string}
      >,
    }));

    // Fallback category: Prefer "other" if existing, else "canned_dry_goods", else first category
    const hasOtherCat = categories.some((c) => c.id === "other");
    const defaultCatId = hasOtherCat ?
      "other" :
      categories.some((c) => c.id === "canned_dry_goods") ?
        "canned_dry_goods" :
        categories.length > 0 ?
          categories[0].id :
          "vegetables";

    const masterFoods: MasterFoodItem[] = masterFoodsSnap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        name: data.name as string,
        normalizedName: (data.normalizedName || "").toLowerCase(),
        aliases: ((data.aliases || []) as string[]).map((a) => a.toLowerCase()),
        categoryId: data.categoryId as string,
        defaultUnit: data.defaultUnit as string,
      };
    });

    const activeItems = activeItemsSnap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        name: data.name as string,
        normalizedName: (data.normalizedName || "").toLowerCase(),
        quantity: (data.quantity as number) || 1,
        unit: (data.unit as string) || "",
        storageLocationId: (data.storageLocationId as string) || "fridge",
        expirationDate: data.expirationDate ? data.expirationDate.toDate() : new Date(),
      };
    });

    // 2. Multimodal extraction with Gemini (Image + OCR text) or fallback parser
    const rawItems = await this._callGeminiToExtractItems(
      ocrText,
      masterFoods,
      imageBase64,
      mimeType
    );

    if (!rawItems || rawItems.length === 0) {
      return [];
    }

    const now = new Date();
    const results: EnrichedParsedItem[] = [];

    // 3. Process, validate, and enrich each raw item
    for (const raw of rawItems) {
      // Step A: Validate raw fields
      if (!raw || typeof raw.rawName !== "string") continue;
      const cleanRawName = raw.rawName.trim();
      const normRawName = normalizeFoodName(cleanRawName);

      if (normRawName.length < 2) continue;

      // Exclude receipt metadata / financial labels that might have leaked
      if (this._isExcludedMetadata(normRawName)) {
        logger.warn(`[ReceiptParserService] Discarding non-food metadata item: "${cleanRawName}"`);
        continue;
      }

      // Step B: Calculate final inventory quantity & unit in backend
      // Business rule: finalQuantity = purchaseQuantity * (packCount > 1 ? packCount : 1)
      const purchaseQty = typeof raw.purchaseQuantity === "number" && raw.purchaseQuantity > 0 ?
        raw.purchaseQuantity :
        1;

      const packMultiplier = typeof raw.packCount === "number" && raw.packCount > 1 ?
        raw.packCount :
        1;

      const finalQuantity = purchaseQty * packMultiplier;

      // Step C: Scoring-based Master Food Matching
      const {matchedFood, matchScore} = this._findBestMasterFoodMatch(normRawName, cleanRawName, masterFoods);

      // Verify item credibility: Must have either matched master food (score >= 0.8) OR contain a known food indicator
      const hasFoodKeyword = this._containsFoodIndicator(normRawName);
      if (!matchedFood && !hasFoodKeyword) {
        logger.warn(
          `[ReceiptParserService] Discarding item "${cleanRawName}" (No master match and no food keyword)`
        );
        continue;
      }

      // Step D: Resolve Category (Backend Business Rule)
      let categoryId: string;
      if (matchedFood) {
        categoryId = matchedFood.categoryId;
      } else {
        // Try inferring from category names
        const matchedCat = categories.find((c) => normRawName.includes(normalizeFoodName(c.name)));
        categoryId = matchedCat ? matchedCat.id : defaultCatId;
      }

      // Step E: Resolve Unit
      // Prefer packUnit (e.g. "hộp" from "Lốc 4 hộp") if packCount was applied,
      // otherwise purchaseUnit, otherwise master food defaultUnit, fallback "món".
      let finalUnit = "món";
      if (packMultiplier > 1 && raw.packUnit && raw.packUnit.trim()) {
        finalUnit = raw.packUnit.trim();
      } else if (raw.purchaseUnit && raw.purchaseUnit.trim()) {
        finalUnit = raw.purchaseUnit.trim();
      } else if (matchedFood && matchedFood.defaultUnit) {
        finalUnit = matchedFood.defaultUnit;
      }

      // Step F: Resolve Storage Location (Strict FOORA Business Rule: default "fridge")
      // Frozen goods (e.g. from frozen_foods category) default to "freezer", otherwise "fridge".
      const storageLocationId = categoryId === "frozen_foods" ? "freezer" : "fridge";

      // Step G: Calculate Expiration Date via InventoryService
      // Prioritizes shelf_life_rules (matching foodId + storageLocationId, taking maxValue),
      // then falls back to food_categories defaultShelfLife (taking maxValue).
      const estimatedExp = await InventoryService.calculateExpirationDate(
        matchedFood?.id || null,
        categoryId,
        storageLocationId,
        now
      );

      // Step H: Duplicate Stock & FEFO Check in Household Inventory
      let duplicateAlert: MatchedExistingStock | null = null;
      const existingMatch = activeItems.find((item) => {
        const itemNorm = item.normalizedName;
        return (
          itemNorm === normRawName ||
          (matchedFood && itemNorm === matchedFood.normalizedName) ||
          (normRawName.length >= 4 && itemNorm === normRawName)
        );
      });

      if (existingMatch) {
        const diffMs = existingMatch.expirationDate.getTime() - now.getTime();
        const daysRemaining = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

        duplicateAlert = {
          itemId: existingMatch.id,
          name: matchedFood?.name || cleanRawName,
          quantity: existingMatch.quantity,
          unit: existingMatch.unit,
          storageLocationName:
            existingMatch.storageLocationId === "freezer" ? "Ngăn đông" : "Ngăn mát",
          expirationDate: existingMatch.expirationDate.toISOString(),
          daysRemaining,
        };
      }

      // Step I: Display Name & Confidence Score
      const displayName = matchedFood ? matchedFood.name : cleanRawName;

      // Realistic confidence: based on extraction & matching quality
      const confidence = matchedFood ?
        Math.min(0.98, Math.max(0.82, matchScore)) :
        0.75;

      results.push({
        rawName: cleanRawName,
        name: displayName,
        normalizedName: normRawName,
        foodId: matchedFood?.id || null,
        categoryId,
        quantity: Math.max(0.1, finalQuantity),
        unit: finalUnit,
        storageLocationId,
        estimatedExpirationDate: estimatedExp.toISOString(),
        confidence,
        matchedExistingItem: duplicateAlert,
      });
    }

    return results;
  }
  /**
   * Calls Gemini 2.5 Flash with multimodal input (Receipt Image + OCR text).
   * Gemini only extracts raw receipt data: rawName, purchaseQuantity, purchaseUnit, etc.
   */
  private static async _callGeminiToExtractItems(
    ocrText: string,
    masterFoods: MasterFoodItem[],
    imageBase64?: string,
    mimeType?: string
  ): Promise<ParsedReceiptItemRaw[]> {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      logger.warn(
        "[ReceiptParserService] GEMINI_API_KEY is not set. Falling back to rule-based line parser."
      );
      return this._fallbackLineParser(ocrText, masterFoods);
    }

    try {
      const ai = new GoogleGenAI({apiKey});

      const promptText = [
        "You are an expert AI food receipt parser specialized in Vietnamese supermarket and grocery receipts ",
        "(e.g. WinMart, Co.opmart, Bách Hóa Xanh, Big C, GO!, Lotte Mart, Aeon, Kingfoodmart, GS25, Circle K).\n\n",
        "YOUR SOLE TASK:\n",
        "Inspect the receipt image (primary) and OCR text (secondary/assistive) to extract ONLY purchased edible food, beverage, condiment, fresh produce, meat, and grocery items.\n\n",
        "CRITICAL EXTRACTION RULES (MUST FOLLOW STRICTLY):\n",
        "1. MULTI-LINE PRODUCT BOUNDARIES (TÊN SẢN PHẨM XUỐNG DÒNG):\n",
        "   - Supermarket receipts often wrap ONE single product across 2 or 3 lines before the quantity and price columns.\n",
        "   - You MUST merge all wrapped lines belonging to the same product into ONE single rawName.\n",
        "   - Example:\n",
        "     Line 1: 'NAM DƯƠNG Sốt'\n",
        "     Line 2: 'Dầu Dấm Trộn'\n",
        "     Line 3: 'Salad 250g'\n",
        "     -> MUST become ONE item: rawName: 'NAM DƯƠNG Sốt Dầu Dấm Trộn Salad 250g'.\n",
        "     -> NEVER create separate items for 'NAM DƯƠNG', 'Sốt', 'Dầu Dấm Trộn', or 'Salad 250g'!\n\n",
        "2. QUANTITY MUST BE READ FROM 'SL' (SỐ LƯỢNG) COLUMN:\n",
        "   - purchaseQuantity MUST come strictly from the 'SL' / quantity column of that item on the receipt.\n",
        "   - NEVER use unit price (Đơn giá), subtotal/total (Thành tiền), barcode, or product specifications (size/weight) as purchaseQuantity!\n",
        "   - Example: 'MỘC CHÂU Sữa thanh trùng không đường H 900ml' with SL: 1, Price: 40,700:\n",
        "     * purchaseQuantity: 1 (from SL column)\n",
        "     * productSize: 900\n",
        "     * productSizeUnit: 'ml'\n",
        "     * DO NOT set purchaseQuantity to 900 or 40,700!\n\n",
        "3. PACK / BUNDLE EXTRACTION:\n",
        "   - If the product text indicates a multi-pack or bundle (e.g. 'Lốc 4 hộp', 'Thùng 24 lon', 'Vỉ 10 quả', 'Gói 6 cái', 'Túi 5 quả', 'Combo 2 chai', 'Set 3 hũ'):\n",
        "     * extract packCount (e.g. 4) and packUnit (e.g. 'hộp').\n",
        "     * purchaseQuantity remains the count from the SL column (e.g. 2).\n",
        "     * Do not perform multiplication yourself; backend will multiply purchaseQuantity * packCount.\n\n",
        "4. VIETNAMESE ACCENT & OCR CORRECTION:\n",
        "   - Supermarket OCR frequently loses diacritical marks or joins words together (e.g. 'DUƠNG' -> 'DƯƠNG', 'MOC CHẦU' -> 'MỘC CHÂU', 'Sữathanh trùngk.đưòng' -> 'Sữa thanh trùng không đường').\n",
        "   - Use the visual receipt image to restore the correct Vietnamese accents, spaces, and spelling.\n",
        "   - Keep visible brand names (e.g. 'NAM DƯƠNG', 'MỘC CHÂU', 'WINECO', 'Vinamilk').\n",
        "   - DO NOT invent new products, DO NOT change to a different food, and DO NOT translate product names to English.\n\n",
        "5. STRICT EXCLUSIONS (DO NOT EXTRACT AS ITEMS):\n",
        "   - Store information: WinMart, address, phone, tax code (MST), cashier/NV, receipt number (PTT/HD), dates, timestamps.\n",
        "   - Table headers & financial figures: 'Giá', 'SL', 'TT', 'KM', 'Tổng giá trị đơn', 'Tổng tiền giảm', 'Tổng tiền thanh toán', '20,200', '40,700', '15,500', '76,400', '-3,100', '73,300'.\n",
        "   - Footers, return policies, QR code instructions, payment methods.\n",
        "   - Non-food household items: plastic bags (túi nilon/xốp/t-shirt), dish soap, detergent, tissues, shampoo.\n\n",
        `OCR TEXT FROM RECEIPT FOR REFERENCE:\n"""\n${ocrText}\n"""`,
      ].join("");

      // Build multimodal contents: receipt image + prompt text
      const parts: Array<{
        text?: string;
        inlineData?: {
          data: string;
          mimeType: string;
        };
      }> = [];

      if (imageBase64) {
        parts.push({
          inlineData: {
            data: imageBase64,
            mimeType: mimeType || "image/jpeg",
          },
        });
      }
      parts.push({text: promptText});

      logger.info(
        `[ReceiptParserService] Calling Gemini 3.6 Flash (hasImage: ${!!imageBase64}, mimeType: ${mimeType || "image/jpeg"}, ocrLength: ${ocrText.length})`
      );

      const response = await ai.models.generateContent({
        model: "gemini-3.6-flash",
        contents: parts,
        config: {
          responseMimeType: "application/json",
          responseSchema: {
            type: Type.ARRAY,
            items: {
              type: Type.OBJECT,
              properties: {
                rawName: {type: Type.STRING},
                purchaseQuantity: {type: Type.NUMBER},
                purchaseUnit: {type: Type.STRING},
                productSize: {type: Type.NUMBER},
                productSizeUnit: {type: Type.STRING},
                packCount: {type: Type.NUMBER},
                packUnit: {type: Type.STRING},
              },
              required: ["rawName", "purchaseQuantity", "purchaseUnit"],
            },
          },
        },
      });

      const responseText = response.text?.trim();
      logger.info("[ReceiptParserService] Gemini response received:", responseText);
      if (!responseText) {
        logger.warn("[ReceiptParserService] Empty Gemini response, using fallback parser.");
        return this._fallbackLineParser(ocrText, masterFoods);
      }

      // Strip markdown code fences if present
      const cleanJson = responseText
        .replace(/^```(?:json)?\s*/i, "")
        .replace(/\s*```$/i, "")
        .trim();

      try {
        const parsed = JSON.parse(cleanJson);
        if (Array.isArray(parsed)) {
          // Runtime validation of each item
          const validatedItems: ParsedReceiptItemRaw[] = [];
          for (const item of parsed) {
            if (
              item &&
              typeof item.rawName === "string" &&
              item.rawName.trim().length >= 2 &&
              typeof item.purchaseQuantity === "number" &&
              item.purchaseQuantity > 0
            ) {
              validatedItems.push({
                rawName: item.rawName.trim(),
                purchaseQuantity: item.purchaseQuantity,
                purchaseUnit: typeof item.purchaseUnit === "string" ? item.purchaseUnit.trim() : "gói",
                productSize: typeof item.productSize === "number" && item.productSize > 0 ? item.productSize : undefined,
                productSizeUnit: typeof item.productSizeUnit === "string" ? item.productSizeUnit.trim() : undefined,
                packCount: typeof item.packCount === "number" && item.packCount > 0 ? item.packCount : undefined,
                packUnit: typeof item.packUnit === "string" ? item.packUnit.trim() : undefined,
              });
            } else {
              logger.warn("[ReceiptParserService] Discarding malformed raw item from Gemini:", item);
            }
          }
          return validatedItems;
        }
      } catch (parseErr) {
        logger.warn(
          "[ReceiptParserService] JSON parse error on Gemini response, falling back to line parser:",
          parseErr
        );
      }

      return this._fallbackLineParser(ocrText, masterFoods);
    } catch (error) {
      logger.error("[ReceiptParserService] Error calling Gemini API:", error);
      return this._fallbackLineParser(ocrText, masterFoods);
    }
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
   */
  private static _findBestMasterFoodMatch(
    normRawName: string,
    cleanRawName: string,
    masterFoods: MasterFoodItem[]
  ): {matchedFood: MasterFoodItem | null; matchScore: number} {
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

  /**
   * Checks if normalized text contains known supermarket receipt non-food metadata
   */
  private static _isExcludedMetadata(norm: string): boolean {
    const excludedKeywords = [
      // Store brands & locations
      "sieu thi", "cua hang", "chi nhanh", "dia chi", "tel", "hotline", "mst",
      "ma so thue", "website", "email", "wifi", "mat khau", "pass wifi",
      "cong ty", "co phan", "tnhh", "winmart", "coopmart", "co opmart",
      "bach hoa xanh", "lotte mart", "big c", "go mart", "circle k", "ministop",
      // Receipt headers/footers & metadata
      "hoa don", "phieu tinh tien", "phieu thanh toan", "phieu thu", "so hd", "ma hd", "so phieu",
      "ptt", "msch", "cot", "hvvvin", "ngay in", "gio in", "ngay", "gio vao", "gio ra",
      "pos", "quay thu ngan", "thu ngan", "nv ban hang", "nhan vien", "khach hang",
      "the tv", "ma kh", "the thanh vien", "diem tich luy", "diem su dung", "diem con lai",
      "cam on quy khach", "hen gap lai", "quy khach", "xin cam on", "tu choi chiu trach",
      "quet qr", "xuat hoa don", "xuathoadon", "thong tin sai", "mat hang",
      // Financial & totals
      "tong gia tri don", "tong tien giam", "tong cong", "tong tien", "tong tt",
      "tien thanh toan", "thanh toan", "tien mat", "tien thua", "tien thoi", "tra lai",
      "chuyen khoan", "the tin dung", "the atm", "giam gia", "chiet khau", "tam tinh",
      "thanh tien", "don gia", "gia", "sl", "so luong", "vat", "thue vat", "khuyen mai",
      "km", "gia20", "sl1",
      // Non-food household supplies commonly on supermarket receipts
      "tui xop", "tui nylon", "tui nilon", "tui t shirt", "tui tu huy", "bao bi",
      "nuoc rua chen", "nuoc lau san", "nuoc giat", "bot giat", "xa bong",
      "dau goi", "sua tam", "giay ve sinh", "khan giay", "bang ve sinh",
      "ban chai", "kem danh rang", "pin aa", "pin aaa", "tui rac",
    ];

    return excludedKeywords.some((kw) => norm.includes(kw));
  }

  /**
   * Checks if line contains common Vietnamese food indicator words
   */
  private static _containsFoodIndicator(norm: string): boolean {
    const foodIndicators = [
      "thit", "heo", "bo", "ga", "vit", "ca", "tom", "muc", "cua", "oc",
      "rau", "cai", "cu", "qua", "trai", "dua", "chuoi", "tao", "cam", "chanh",
      "sua", "trung", "dau", "dau hu", "cha", "gio", "xuc xich", "banh",
      "gao", "mi", "bun", "pho", "mien", "chao", "nuoc mam", "nuoc tuong",
      "muoi", "duong", "tieu", "ot", "toi", "hanh", "gung", "sa", "nam",
      "canh", "thuc pham", "do hop", "ca hop", "pate", "bo sua", "sua chua",
      "tra", "ca phe", "nuoc ep", "sinh to", "khoai", "bap", "ngo", "sot", "dam",
      "salad", "xa lach",
    ];

    const tokens = norm.split(/\s+/);
    return tokens.some((token) => foodIndicators.includes(token));
  }

  /**
   * Conservative fallback line parser used when Gemini is unavailable or fails.
   * Prioritizes precision over recall:
   * - Eliminates all metadata, prices, and totals.
   * - Groups wrapped lines with simple lookahead.
   * - Only creates items that match master foods or strong food keywords.
   * - Never guesses or creates bogus items when uncertain.
   */
  private static _fallbackLineParser(
    ocrText: string,
    masterFoods: MasterFoodItem[]
  ): ParsedReceiptItemRaw[] {
    const lines = ocrText
      .split(/\r?\n/)
      .map((l) => l.trim())
      .filter((l) => l.length >= 2);

    const items: ParsedReceiptItemRaw[] = [];
    let i = 0;

    while (i < lines.length) {
      const line = lines[i];
      const norm = normalizeFoodName(line);

      // Skip metadata or purely financial lines
      if (this._isExcludedMetadata(norm) || /^[0-9,.\s\-+]+$/.test(line)) {
        i++;
        continue;
      }

      // Check if next lines are wrapped continuations (e.g. no price/number, short fragment)
      let combinedName = line;
      let j = i + 1;
      while (j < lines.length && j <= i + 2) {
        const nextLine = lines[j];
        const nextNorm = normalizeFoodName(nextLine);

        // Stop if next line is metadata, price line, or distinct product
        if (
          this._isExcludedMetadata(nextNorm) ||
          /^[0-9,.\s\-+]+$/.test(nextLine) ||
          this._containsFoodIndicator(nextNorm)
        ) {
          break;
        }

        // Merge fragment
        if (nextLine.length < 30) {
          combinedName += " " + nextLine;
          j++;
        } else {
          break;
        }
      }
      i = j;

      // Extract quantity and product size from text if present
      let purchaseQuantity = 1;
      const purchaseUnit = "gói";
      let productSize: number | undefined;
      let productSizeUnit: string | undefined;
      let packCount: number | undefined;
      let packUnit: string | undefined;

      // Check product size: e.g. 250g, 900ml, 300g, 1kg
      const sizeMatch = combinedName.match(/(\d+(?:[.,]\d+)?)\s*(g|kg|ml|l)\b/i);
      if (sizeMatch) {
        productSize = parseFloat(sizeMatch[1].replace(",", "."));
        productSizeUnit = sizeMatch[2].toLowerCase();
      }

      // Check pack bundle: e.g. "loc 4 hop", "thung 24 lon", "vi 10 qua"
      const bundleMatch = normalizeFoodName(combinedName).match(
        /(?:loc|thung|vi|hop|goi|set|combo|tui)\s*(\d+)\s*(hop|lon|chai|qua|trai|goi|cai|hu)/i
      );
      if (bundleMatch) {
        packCount = parseInt(bundleMatch[1], 10);
        packUnit = bundleMatch[2].toLowerCase();
      }

      // Check explicit SL (Số lượng) notation in the line: e.g. "SL 2", "SL: 1", "x 2"
      const slMatch = combinedName.match(/(?:sl[:\s]*|x\s*)(\d+)\b/i);
      if (slMatch) {
        purchaseQuantity = parseInt(slMatch[1], 10);
      }

      // Clean item name from trailing numbers, prices, and symbols
      const cleanName = combinedName
        .replace(/(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?\s*(?:d|vnd|đ)?)$/i, "")
        .replace(/^[0-9\s.*#\-_/]+/, "")
        .trim();

      const normClean = normalizeFoodName(cleanName);
      if (normClean.length < 3 || this._isExcludedMetadata(normClean)) {
        continue;
      }

      // Require high confidence: Must match master food OR contain confirmed food keyword
      const hasMatch = masterFoods.some((f) => normClean.includes(f.normalizedName) || f.normalizedName.includes(normClean));
      const hasFoodKeyword = this._containsFoodIndicator(normClean);

      if (hasMatch || hasFoodKeyword) {
        items.push({
          rawName: cleanName,
          purchaseQuantity: Math.max(1, purchaseQuantity),
          purchaseUnit: packUnit || productSizeUnit || purchaseUnit,
          productSize,
          productSizeUnit,
          packCount,
          packUnit,
        });
      }
    }

    return items.slice(0, 25);
  }
}
