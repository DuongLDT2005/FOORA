import {GoogleGenAI, Schema, ThinkingLevel, Type} from "@google/genai";
import {HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {ASSISTANT_SYSTEM_INSTRUCTION} from "./assistant_prompt";

/**
 * Starts the fallback model when the primary has not answered by then; most
 * answers take 1-2 s, so a slower one is usually stuck.
 */
const HEDGE_DELAY_MS = 3500;
const ATTEMPT_TIMEOUT_MS = 15000;
const MAX_OUTPUT_TOKENS = 2048;

export interface GeminiTransport {
  generate: (
    model: string,
    contents: string,
    signal: AbortSignal
  ) => Promise<string | undefined>;
}

/**
 * Attempts in order, from backend config: `AI_ASSISTANT_MODEL` answers first,
 * then each of the comma-separated `AI_ASSISTANT_FALLBACK_MODELS`. Repeating
 * the primary is allowed: a fast model's slow or broken answer is random, so
 * a second call to it usually beats a slower model.
 * @return {string[]} Gemini model ids, one per attempt.
 */
export function assistantModels(): string[] {
  const primary = process.env.AI_ASSISTANT_MODEL?.trim() ||
    "gemini-3.5-flash-lite";
  const fallbacks = (process.env.AI_ASSISTANT_FALLBACK_MODELS ??
    `${primary},gemini-3.1-flash-lite`)
    .split(",").map((model) => model.trim()).filter(Boolean);
  return [primary, ...fallbacks];
}

/**
 * Maps a provider error to a callable error with an actionable message.
 * @param {unknown} error Error carrying an HTTP `status`.
 * @return {HttpsError | null} Callable error, or null if unknown.
 */
export function assistantModelError(error: unknown): HttpsError | null {
  const status = (error as {status?: unknown})?.status;
  if (status === 402) {
    return new HttpsError("failed-precondition",
      "Dịch vụ AI đang yêu cầu thanh toán hoặc đã hết hạn mức. " +
      "Hãy kiểm tra cấu hình Gemini API.");
  }
  if (status === 401 || status === 403) {
    return new HttpsError("failed-precondition",
      "Dịch vụ AI không chấp nhận khóa API. Hãy kiểm tra cấu hình Gemini.");
  }
  if (status === 404) {
    return new HttpsError("failed-precondition",
      "Model AI hiện không khả dụng. Hãy kiểm tra cấu hình model.");
  }
  if (status === 429 || (typeof status === "number" && status >= 500)) {
    return new HttpsError("unavailable",
      "Dịch vụ AI đang quá tải hoặc hết hạn mức tạm thời. Hãy thử lại sau.");
  }
  return null;
}

/** Shape enforced by Gemini; the backend validator still checks each field. */
const assistantResponseSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    reply: {type: Type.STRING},
    recipes: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          title: {type: Type.STRING},
          servings: {type: Type.INTEGER},
          ingredients: {
            type: Type.ARRAY,
            items: {
              type: Type.OBJECT,
              properties: {
                name: {type: Type.STRING},
                ref: {type: Type.STRING},
                quantity: {type: Type.NUMBER},
                unit: {type: Type.STRING},
              },
              required: ["name"],
            },
          },
        },
        required: ["title", "ingredients"],
      },
    },
    actions: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        // ref is required (empty for new foods) and comes right after type:
        // without it the model often left out the inventory link.
        properties: {
          type: {type: Type.STRING,
            enum: ["add_inventory", "consume", "discard", "set_quantity"]},
          ref: {type: Type.STRING},
          name: {type: Type.STRING},
          quantity: {type: Type.NUMBER},
          unit: {type: Type.STRING},
          categoryId: {type: Type.STRING},
          storageLocationId: {type: Type.STRING, enum: ["fridge", "freezer"]},
        },
        required: ["type", "ref", "name"],
        propertyOrdering: ["type", "ref", "name", "quantity", "unit",
          "categoryId", "storageLocationId"],
      },
    },
  },
  required: ["reply", "recipes", "actions"],
  propertyOrdering: ["reply", "recipes", "actions"],
};

/** True when a model rejects the requested thinking level. */
function isThinkingConfigError(error: unknown): boolean {
  const status = (error as {status?: unknown})?.status;
  const message = String((error as {message?: unknown})?.message ?? "");
  return status === 400 && /thinking/i.test(message);
}

const clients = new Map<string, GoogleGenAI>();

/**
 * Gemini SDK transport. Gemini 3 thinks at a high level by default, which
 * made answers take 10-25 s; the lowest level the model accepts is used.
 * @param {string} apiKey Gemini key from the Functions secret.
 * @return {GeminiTransport} Transport reusing one client per key.
 */
function geminiTransport(apiKey: string): GeminiTransport {
  let ai = clients.get(apiKey);
  if (!ai) {
    ai = new GoogleGenAI({apiKey});
    clients.set(apiKey, ai);
  }
  const client = ai;
  return {
    generate: async (model, contents, signal) => {
      const levels = [ThinkingLevel.MINIMAL, ThinkingLevel.LOW, undefined];
      for (const level of levels) {
        try {
          const response = await client.models.generateContent({
            model,
            contents,
            config: {
              systemInstruction: ASSISTANT_SYSTEM_INSTRUCTION,
              responseMimeType: "application/json",
              responseSchema: assistantResponseSchema,
              // Gemini 3 loops (e.g. "quả0000...") below its default
              // temperature, so the default is kept.
              maxOutputTokens: MAX_OUTPUT_TOKENS,
              ...(level ? {thinkingConfig: {thinkingLevel: level}} : {}),
              abortSignal: signal,
            },
          });
          return response.text;
        } catch (error) {
          if (!level || !isThinkingConfigError(error)) throw error;
        }
      }
      return undefined;
    },
  };
}

/**
 * Asks Gemini for the structured assistant answer. The first attempt starts
 * at once; the next one starts when a running attempt fails or every
 * `hedgeMs` without an answer, and the first answer that `accept` approves
 * wins (the other calls are aborted). When no answer is approved, the last rejected one
 * is returned with `accepted: false` so the caller can still use it. A
 * rejected key stops at once.
 * @param {string} apiKey Gemini key from the Functions secret.
 * @param {string} contents Prompt context as JSON.
 * @param {function} accept Whether an answer is good enough to stop.
 * @param {object} options Per-model timeout and hedge delay.
 * @param {GeminiTransport} transport Model client.
 * @return {Promise<object>} JSON text, model id and whether it was approved.
 */
export function generateAssistantJson(
  apiKey: string,
  contents: string,
  accept: (text: string) => boolean = () => true,
  options: {timeoutMs: number; hedgeMs: number} =
  {timeoutMs: ATTEMPT_TIMEOUT_MS, hedgeMs: HEDGE_DELAY_MS},
  transport: GeminiTransport = geminiTransport(apiKey)
): Promise<{text: string; model: string; accepted: boolean}> {
  const models = assistantModels();
  return new Promise((resolve, reject) => {
    const controllers: AbortController[] = [];
    let started = 0;
    let running = 0;
    let settled = false;
    let lastError: unknown;
    let rejected: {text: string; model: string} | undefined;
    // A model that hit its quota (429) fails again at once; skip its retries.
    const exhausted = new Set<string>();

    const settle = (outcome: () => void): void => {
      if (settled) return;
      settled = true;
      clearInterval(hedgeTimer);
      controllers.forEach((controller) => controller.abort());
      outcome();
    };

    const start = (index: number): void => {
      if (settled || index !== started) return;
      while (started < models.length && exhausted.has(models[started])) {
        started++;
      }
      if (started >= models.length) return;
      index = started;
      started++;
      running++;
      const model = models[index];
      const controller = new AbortController();
      controllers.push(controller);
      const timer = setTimeout(() => controller.abort(), options.timeoutMs);
      transport.generate(model, contents, controller.signal)
        .then((text) => {
          const content = text?.trim();
          if (!content) throw new Error(`Gemini ${model} returned no content`);
          if (!accept(content)) {
            rejected = {text: content, model};
            throw new Error(`Gemini ${model} returned an unusable answer`);
          }
          settle(() => resolve({text: content, model, accepted: true}));
        })
        .catch((error) => {
          if (settled) return;
          const status = (error as {status?: unknown})?.status;
          if (status === 401 || status === 403) {
            settle(() => reject(assistantModelError(error) ?? error));
            return;
          }
          if (status === 429) exhausted.add(model);
          lastError = error;
          logger.warn(`[AssistantGemini] ${model} failed`, error);
          start(started);
        })
        .finally(() => {
          clearTimeout(timer);
          running--;
          if (running === 0 && started >= models.length) {
            const fallback = rejected;
            if (fallback) {
              settle(() => resolve({...fallback, accepted: false}));
              return;
            }
            settle(() => reject(assistantModelError(lastError) ??
              new HttpsError("unavailable",
                "Trợ lý AI đang bận, vui lòng thử lại sau ít phút.")));
          }
        });
    };

    const hedgeTimer = setInterval(() => start(started), options.hedgeMs);
    start(0);
  });
}
