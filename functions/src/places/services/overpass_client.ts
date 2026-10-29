import {OverpassElement} from "./overpass_query";

export type Fetcher = (input: string, init?: RequestInit) => Promise<Response>;
export type Waiter = (milliseconds: number) => Promise<void>;
export type Clock = () => number;

/** Overpass asks clients to wait at least 30 s after a 429/504. */
export const RETRY_DELAY_MS = 30_000;
/** Slightly longer than the `[timeout:25]` given to Overpass itself. */
export const REQUEST_TIMEOUT_MS = 28_000;
/** Total budget, kept below the callable's 70 s timeout. */
export const QUERY_BUDGET_MS = 62_000;

interface OverpassResponse {
  elements?: OverpassElement[];
}

export class OverpassError extends Error {
  /**
   * @param retryable Overpass asked us to back off (429/504).
   * @param failover Another mirror may succeed (network error, 429, 5xx).
   */
  constructor(
    message: string,
    readonly retryable = false,
    readonly failover = retryable
  ) {
    super(message);
    this.name = "OverpassError";
  }
}

/** Mirrors are tried in order when one is unreachable or overloaded. */
export const DEFAULT_OVERPASS_ENDPOINTS = [
  "https://overpass-api.de/api/interpreter",
  "https://overpass.private.coffee/api/interpreter",
  "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
];

/** Splits a comma-separated `OVERPASS_URL` into endpoints. */
export function parseOverpassEndpoints(value: string): string[] {
  const endpoints = value.split(",").map((url) => url.trim()).filter(Boolean);
  return endpoints.length > 0 ? endpoints : DEFAULT_OVERPASS_ENDPOINTS;
}

/** Below this, a request is unlikely to finish before the callable timeout. */
const MIN_REQUEST_MS = 10_000;

/** A small, injectable Overpass client for server-side requests only. */
export class OverpassClient {
  private readonly endpoints: string[];

  constructor(
    endpoints: string | string[],
    private readonly fetcher: Fetcher = fetch,
    private readonly wait: Waiter = (ms) =>
      new Promise((resolve) => setTimeout(resolve, ms)),
    private readonly now: Clock = () => Date.now()
  ) {
    this.endpoints = typeof endpoints === "string" ?
      parseOverpassEndpoints(endpoints) :
      endpoints;
  }

  async query(query: string): Promise<OverpassElement[]> {
    const startedAt = this.now();
    const remaining = () => QUERY_BUDGET_MS - (this.now() - startedAt);
    const errors: string[] = [];
    let lastError: OverpassError | undefined;

    for (const endpoint of this.endpoints) {
      if (lastError && remaining() < MIN_REQUEST_MS) break;
      try {
        return await this.request(
          endpoint,
          query,
          Math.min(REQUEST_TIMEOUT_MS, remaining())
        );
      } catch (error) {
        if (!(error instanceof OverpassError) || !error.failover) {
          throw error;
        }
        lastError = error;
        errors.push(`${new URL(endpoint).host}: ${error.message}`);
      }
    }

    // With a single endpoint, one deliberately slow retry prevents a fleet of
    // clients from creating a burst during an Overpass outage. Skip it when
    // the remaining budget cannot fit the wait plus a useful request.
    if (
      this.endpoints.length === 1 &&
      lastError?.retryable &&
      remaining() - RETRY_DELAY_MS >= MIN_REQUEST_MS
    ) {
      await this.wait(RETRY_DELAY_MS);
      return this.request(
        this.endpoints[0],
        query,
        Math.min(REQUEST_TIMEOUT_MS, remaining())
      );
    }

    throw new OverpassError(errors.join("; "), lastError?.retryable ?? false);
  }

  private async request(
    endpoint: string,
    query: string,
    timeoutMs: number
  ): Promise<OverpassElement[]> {
    let response: Response;
    try {
      response = await this.fetcher(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent": "FOORA/1.0 (com.foora.foora; contact: foora.team@gmail.com)",
        },
        body: new URLSearchParams({data: query}).toString(),
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (error) {
      throw new OverpassError(describeFetchError(error), false, true);
    }

    if (response.status === 429 || response.status === 504) {
      throw new OverpassError(`HTTP ${response.status}`, true);
    }
    if (!response.ok) {
      // 4xx means the query itself is wrong, so other mirrors fail too.
      throw new OverpassError(
        `HTTP ${response.status}`,
        false,
        response.status >= 500
      );
    }

    const body = await response.json() as OverpassResponse;
    return Array.isArray(body.elements) ? body.elements : [];
  }
}

/** `fetch failed` hides the real reason (DNS, reset, TLS) in `cause`. */
function describeFetchError(error: unknown): string {
  if (!(error instanceof Error)) return "Không thể kết nối máy chủ bản đồ.";
  const cause = (error as {cause?: {code?: string; message?: string}}).cause;
  const detail = cause?.code ?? cause?.message;
  return detail ? `${error.message} (${detail})` : error.message;
}
