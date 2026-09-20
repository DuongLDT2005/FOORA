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
  photoUrl?: string | null;
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
  photoUrl?: string | null;
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
        photoUrl: (data.photoUrl as string) || null,
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
        photoUrl: matchedFood?.photoUrl || null,
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
        "Bạn là chuyên gia thị giác AI phân tích hóa đơn siêu thị Việt Nam (WinMart, Co.opmart, Bách Hóa Xanh, Big C, GO!, Lotte Mart, Aeon, Kingfoodmart, GS25, Circle K, v.v.).\n\n",
        "NGUYÊN TẮC QUAN TRỌNG NHẤT VỀ NGUỒN DỮ LIỆU:\n",
        "- HÌNH ẢNH HÓA ĐƠN LÀ NGUỒN CHÂN LÝ DUY NHẤT (PRIMARY GROUND TRUTH): Hãy nhìn trực tiếp hình ảnh để đọc layout, bảng cột, vị trí xuống dòng, tên sản phẩm và cột số lượng (SL).\n",
        "- VĂN BẢN OCR CHỈ LÀ PHỤ TRỢ (SECONDARY/ASSISTIVE): OCR từ camera di động thường bị ngắt dòng sai, dính chữ, nhảy hàng hoặc mất dấu. NẾU OCR VÀ HÌNH ẢNH CÓ MÂU THUẪN, BẠN BẮT BUỘC PHẢI THEO HÌNH ẢNH!\n\n",
        "NHIỆM VỤ:\n",
        "Trích xuất danh sách các sản phẩm thực phẩm, đồ uống, gia vị, đồ ăn tươi sống/chế biến từ hóa đơn.\n\n",
        "QUY TẮC BẮT BUỘC (TUÂN THỦ TUYỆT ĐỐI):\n\n",
        "1. GHÉP TÊN SẢN PHẨM NHIỀU DÒNG (DỰA THEO BẢNG CỘT TRÊN ẢNH):\n",
        "   - Nhìn hình ảnh: Một mặt hàng thường in tên dài trên 2-3 dòng, nhưng toàn bộ các dòng đó CHỈ ỨNG VỚI 1 DÒNG SỐ LƯỢNG (SL) VÀ THÀNH TIỀN ở bên phải hoặc ngay dưới.\n",
        "   - CHỈ TẠO 1 SẢN PHẨM MỚI KHI CÓ DÒNG TÍNH TIỀN / SỐ LƯỢNG MỚI TRÊN ẢNH.\n",
        "   - Các dòng ghi quy cách, hương vị, dung tích (ví dụ: 'Salad 250g', 'Dầu Dấm Trộn', 'Không đường', '900ml', 'Lốc 4 hộp', 'Vị dâu') BẮT BUỘC PHẢI GHÉP NỐI vào tên sản phẩm phía trên tạo thành một rawName duy nhất hoàn chỉnh.\n",
        "   - TUYỆT ĐỐI KHÔNG tạo item riêng cho các mảnh như 'Salad 250g', 'Dầu Dấm Trộn'!\n\n",
        "2. SỐ LƯỢNG (purchaseQuantity) BẮT BUỘC LẤY TỪ CỘT 'SL' TRÊN ẢNH:\n",
        "   - Nhìn trực quan cột 'SL' / 'Số lượng' trên ảnh hóa đơn.\n",
        "   - CẤM lấy Đơn giá, Thành tiền, Mã vạch hay Quy cách (250g, 900ml) làm số lượng mua!\n\n",
        "3. ĐÓNG GÓI / COMBO / LỐC (PACK / BUNDLE):\n",
        "   - Nếu tên trên ảnh có 'Lốc 4 hộp', 'Thùng 24 lon', 'Vỉ 10 quả', 'Gói 6 cái', 'Túi 5 quả':\n",
        "     * packCount: số lượng trong lốc (ví dụ: 4)\n",
        "     * packUnit: đơn vị trong lốc (ví dụ: 'hộp')\n",
        "     * purchaseQuantity: vẫn là số lượng ghi ở cột SL (ví dụ mua 2 lốc thì SL = 2).\n\n",
        "4. LOẠI BỎ THÔNG TIN KHÔNG PHẢI THỰC PHẨM:\n",
        "   - Tiêu đề siêu thị, địa chỉ, MST, nhân viên, số hóa đơn, ngày giờ.\n",
        "   - Tiêu đề bảng: 'Giá', 'SL', 'TT', 'KM', tổng tiền thanh toán, tiền thối.\n",
        "   - Đồ gia dụng: túi xốp/túi nilon, nước rửa chén, xà phòng, khăn giấy, hóa mỹ phẩm.\n\n",
        "VÍ DỤ MẪU (FEW-SHOT EXAMPLES):\n\n",

        "--- VÍ DỤ 1: SẢN PHẨM TÊN TRẢI QUA 3 DÒNG (CHỈ 1 DÒNG SL & GIÁ) ---\n",
        "Hình ảnh hiển thị:\n",
        "NAM DƯƠNG Sốt                          (dòng 1 - tên thương hiệu)\n",
        "Dầu Dấm Trộn                           (dòng 2 - loại sản phẩm)\n",
        "Salad 250g      20,200   1   20,200    (dòng 3 - quy cách + Giá + SL + TT)\n",
        "Kết quả JSON mong đợi:\n",
        "[\n",
        "  {\"rawName\": \"NAM DƯƠNG Sốt Dầu Dấm Trộn Salad 250g\", \"purchaseQuantity\": 1, \"purchaseUnit\": \"chai\", \"productSize\": 250, \"productSizeUnit\": \"g\"}\n",
        "]\n\n",

        "--- VÍ DỤ 2: SẢN PHẨM TÊN 3 DÒNG VỚI CHỮ MÔ TẢ 'THANH TRÙNG', 'K.ĐƯỜNG' ---\n",
        "Hình ảnh hiển thị:\n",
        "MỘC CHÂU Sữa                           (dòng 1)\n",
        "thanh trùng                            (dòng 2 - mô tả sản xuất, KHÔNG phải SL)\n",
        "k.đường H 900ml   40,700   1   40,700  (dòng 3 - quy cách + Giá + SL + TT)\n",
        "Kết quả JSON mong đợi:\n",
        "[\n",
        "  {\"rawName\": \"MỘC CHÂU Sữa thanh trùng k.đường H 900ml\", \"purchaseQuantity\": 1, \"purchaseUnit\": \"hộp\", \"productSize\": 900, \"productSizeUnit\": \"ml\"}\n",
        "]\n\n",
        "LÝ DO: 'thanh trùng' và 'k.đường' là MÔ TẢ thuộc tính của sản phẩm, KHÔNG PHẢI sản phẩm riêng. Chỉ có 1 dòng SL=1, do đó chỉ tạo 1 item duy nhất.\n\n",

        "--- VÍ DỤ 3: SẢN PHẨM RAU CỦ VỚI KHUYẾN MÃI ---\n",
        "Hình ảnh hiển thị:\n",
        "WINECO Xà lách\n",
        "lolo xanh L1 300g   15,500   1   15,500\n",
        "                              KM: -3,100\n",
        "Kết quả JSON mong đợi:\n",
        "[\n",
        "  {\"rawName\": \"WINECO Xà lách lolo xanh L1 300g\", \"purchaseQuantity\": 1, \"purchaseUnit\": \"gói\", \"productSize\": 300, \"productSizeUnit\": \"g\"}\n",
        "]\n\n",

        "--- VÍ DỤ 4: SẢN PHẨM LỐC / COMBO ---\n",
        "Hình ảnh hiển thị:\n",
        "TH Sữa chua ăn nha đam Lốc 4x100g   SL: 2   ĐG: 32.000   TT: 64.000\n",
        "Kết quả JSON mong đợi:\n",
        "[\n",
        "  {\"rawName\": \"TH Sữa chua ăn nha đam Lốc 4x100g\", \"purchaseQuantity\": 2, \"purchaseUnit\": \"lốc\", \"productSize\": 100, \"productSizeUnit\": \"g\", \"packCount\": 4, \"packUnit\": \"hộp\"}\n",
        "]\n\n",

        imageBase64 ?
          `LƯU Ý: HÃY ƯU TIÊN ĐỌC TRỰC TIẾP TỪ ẢNH TRÊN. Dưới đây chỉ là văn bản OCR thô để bạn tham khảo thêm khi gặp chữ mờ:\n"""\n${ocrText}\n"""` :
          `VĂN BẢN OCR TỪ HÓA ĐƠN:\n"""\n${ocrText}\n"""`,

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

      // Retry with backoff for transient 503 (high demand) / 429 errors
      let response: Awaited<ReturnType<typeof ai.models.generateContent>> | null = null;
      const MAX_RETRIES = 3;

      for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
        try {
          response = await ai.models.generateContent({
            model: "gemini-3.6-flash",
            contents: parts,
            config: {
              temperature: 0.1,
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
          break; // Succeeded!
        } catch (callErr: unknown) {
          const errObj = callErr as {status?: number; message?: string};
          const isRetryable =
            errObj?.status === 503 ||
            errObj?.status === 429 ||
            (typeof errObj?.message === "string" &&
              (errObj.message.includes("503") ||
                errObj.message.includes("high demand") ||
                errObj.message.includes("UNAVAILABLE")));

          if (isRetryable && attempt < MAX_RETRIES) {
            const delayMs = attempt * 2000;
            logger.warn(
              `[ReceiptParserService] Gemini returned ${errObj?.status || 503} (high demand). Retrying attempt ${attempt + 1}/${MAX_RETRIES} in ${delayMs}ms...`
            );
            await new Promise((resolve) => setTimeout(resolve, delayMs));
          } else {
            throw callErr;
          }
        }
      }

      const responseText = response?.text?.trim();
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

          // Safeguard / Heuristic: Merge any orphan fragment that slipped through
          // E.g. rawName is just a size/unit like "Salad 250g", "250g", "Vị Dâu" without a proper subject
          const mergedItems: ParsedReceiptItemRaw[] = [];
          const orphanFragmentRegex = /^(\d+\s*(g|kg|ml|l|gr)|salad\s*\d+\s*(g|kg|ml|l)|vị\s+\w+|không\s+đường|có\s+đường)$/i;

          for (const item of validatedItems) {
            if (mergedItems.length > 0 && orphanFragmentRegex.test(item.rawName.trim())) {
              logger.info(`[ReceiptParserService] Merging detected orphan fragment "${item.rawName}" into previous item "${mergedItems[mergedItems.length - 1].rawName}"`);
              const prev = mergedItems[mergedItems.length - 1];
              prev.rawName = `${prev.rawName} ${item.rawName}`.trim();
              if (item.productSize && !prev.productSize) {
                prev.productSize = item.productSize;
                prev.productSizeUnit = item.productSizeUnit;
              }
            } else {
              mergedItems.push(item);
            }
          }

          return mergedItems;
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

      // Check if next lines are wrapped continuations (multi-line product name on Vietnamese receipts).
      // A product name can span 2-4 lines. We stop ONLY when we detect a definite price/SL line.
      // IMPORTANT: Do NOT stop on food-descriptor words like 'thanh trung', 'dam', 'tron',
      // 'salad', 'k.duong' — these are sub-lines of the same product, not separate products.
      let combinedName = line;
      let j = i + 1;
      while (j < lines.length && j <= i + 4) {
        const nextLine = lines[j];
        const nextNorm = normalizeFoodName(nextLine);

        // Stop on definite price / receipt metadata line
        if (
          this._isExcludedMetadata(nextNorm) ||
          // A line that is ONLY digits, commas, spaces — it's a price/SL column line
          /^[\d,.\s\-+]+$/.test(nextLine.trim()) ||
          // A line that ends with a clear money amount pattern: "40,700   1   40,700"
          /\d{1,3}(?:[,.]\d{3})+\s+\d+\s+\d{1,3}(?:[,.]\d{3})+/.test(nextLine)
        ) {
          break;
        }

        // Merge if it looks like a product sub-line (short, no standalone price column)
        if (nextLine.length < 40) {
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
