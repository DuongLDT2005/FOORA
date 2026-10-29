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
  constructor(message: string, readonly retryable = false) {
    super(message);
    this.name = "OverpassError";
  }
}

/** A small, injectable Overpass client for server-side requests only. */
export class OverpassClient {
  constructor(
    private readonly endpoint: string,
    private readonly fetcher: Fetcher = fetch,
    private readonly wait: Waiter = (ms) =>
      new Promise((resolve) => setTimeout(resolve, ms)),
    private readonly now: Clock = () => Date.now()
  ) {}

  async query(query: string): Promise<OverpassElement[]> {
    const startedAt = this.now();
    try {
      return await this.request(query, REQUEST_TIMEOUT_MS);
    } catch (error) {
      if (!(error instanceof OverpassError) || !error.retryable) {
        throw error;
      }
      // One deliberately slow retry prevents a fleet of clients from creating
      // a burst during an Overpass outage. Skip it when the remaining budget
      // cannot fit the wait plus a useful request.
      const remaining = QUERY_BUDGET_MS - (this.now() - startedAt) -
        RETRY_DELAY_MS;
      if (remaining < 10_000) {
        throw error;
      }
      await this.wait(RETRY_DELAY_MS);
      return this.request(query, Math.min(REQUEST_TIMEOUT_MS, remaining));
    }
  }

  private async request(
    query: string,
    timeoutMs: number
  ): Promise<OverpassElement[]> {
    let response: Response;
    try {
      response = await this.fetcher(this.endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent": "FOORA/1.0 (com.foora.foora; contact: foora.team@gmail.com)",
        },
        body: new URLSearchParams({data: query}).toString(),
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (error) {
      throw new OverpassError(
        error instanceof Error ? error.message : "Không thể kết nối máy chủ bản đồ."
      );
    }

    if (response.status === 429 || response.status === 504) {
      throw new OverpassError("Máy chủ bản đồ đang bận.", true);
    }
    if (!response.ok) {
      throw new OverpassError(`Máy chủ bản đồ trả về lỗi ${response.status}.`);
    }

    const body = await response.json() as OverpassResponse;
    return Array.isArray(body.elements) ? body.elements : [];
  }
}
