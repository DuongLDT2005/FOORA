/**
 * Synthetic (demo) traffic generator for a GA4 property via the
 * Measurement Protocol.
 *
 * Every event and user is tagged `data_source = synthetic` so it can always
 * be filtered out. Point it at a dedicated demo property, never at the
 * property that receives real user data.
 *
 * The output is deterministic per calendar day (seeded RNG), so re-running a
 * day produces the same users/sessions instead of random duplicates.
 */

import * as crypto from "crypto";

const VN_OFFSET_MS = 7 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const MP_ENDPOINT = "https://www.google-analytics.com/mp/collect";
const MP_DEBUG_ENDPOINT = "https://www.google-analytics.com/debug/mp/collect";
const MAX_EVENTS_PER_REQUEST = 25;
/** GA4 rejects events older than 72h; keep a safety margin. */
export const MAX_BACKFILL_MS = 71 * 60 * 60 * 1000;

export interface SyntheticConfig {
  /** First day of the simulated timeline, "YYYY-MM-DD" (Vietnam time). */
  startDate: string;
}

interface MpEvent {
  name: string;
  params: Record<string, string | number>;
  timestamp_micros: number;
}

export interface MpPayload {
  client_id: string;
  user_id: string;
  user_properties: Record<string, {value: string}>;
  user_location: Record<string, string>;
  device: Record<string, string>;
  events: MpEvent[];
}

export interface DayPlan {
  date: string;
  dayIndex: number;
  totalUsers: number;
  activeUsers: number;
  newUsers: number;
  sessions: number;
  events: number;
  payloads: MpPayload[];
}

// --- Seeded RNG ------------------------------------------------------------

function hashString(value: string): number {
  let h = 2166136261;
  for (let i = 0; i < value.length; i++) {
    h ^= value.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function rng(seed: string): () => number {
  let a = hashString(seed);
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const ID_ALPHABET =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

/** Stable random-looking id (Firestore auto-id style) derived from `seed`. */
export function mockId(seed: string, length = 20): string {
  const bytes = crypto.createHash("sha256").update(seed).digest();
  let id = "";
  for (let i = 0; i < length; i++) id += ID_ALPHABET[bytes[i] % ID_ALPHABET.length];
  return id;
}

/** Firebase-Auth-style 28-char UID for a synthetic user id (e.g. "syn_001"). */
export function mockUid(syntheticId: string): string {
  return mockId(`uid-${syntheticId}`, 28);
}

// --- Date helpers (Vietnam time) -------------------------------------------

/** Midnight of `date` in Vietnam time, as a UTC epoch in ms. */
export function vnDayStartMs(date: string): number {
  const [y, m, d] = date.split("-").map(Number);
  return Date.UTC(y, m - 1, d) - VN_OFFSET_MS;
}

export function vnDateOf(epochMs: number): string {
  return new Date(epochMs + VN_OFFSET_MS).toISOString().slice(0, 10);
}

export function addDays(date: string, days: number): string {
  return vnDateOf(vnDayStartMs(date) + days * DAY_MS);
}

function dayIndexOf(config: SyntheticConfig, date: string): number {
  return Math.round(
    (vnDayStartMs(date) - vnDayStartMs(config.startDate)) / DAY_MS
  );
}

// --- Growth model ----------------------------------------------------------

/**
 * Cumulative registered users at the end of day `t` (0 = start date).
 *  - Week 1: up to 5 early testers (sparse usage).
 *  - Day 7 → 23: accelerating growth from 5 up to 10 users.
 *  - Day 24 → 26: flat at 10.
 *  - From day 27 (25/10): +1 user, then +1 more after a random gap of
 *    1–7 days, repeated indefinitely (seeded, so every run agrees).
 */
export function cumulativeUsers(t: number): number {
  if (t < 0) return 0;
  const week1 = [1, 2, 2, 3, 4, 4, 5];
  if (t < 7) return week1[t];
  if (t <= 23) return Math.round(5 + 5 * Math.pow((t - 7) / 16, 1.4));
  let count = 10;
  for (const day of growthDaysUpTo(t)) {
    if (day <= t) count++;
  }
  return count;
}

const FIRST_GROWTH_DAY = 27;
const growthDays: number[] = [FIRST_GROWTH_DAY];

/** Days (after the 10-user plateau) on which one new user signs up. */
function growthDaysUpTo(t: number): number[] {
  const r = rng("growth-gaps");
  // Replay the seeded gaps so the sequence is identical on every call.
  for (let i = 1; i < growthDays.length; i++) r();
  while (growthDays[growthDays.length - 1] < t) {
    const gap = 1 + Math.floor(r() * 7); // 1..7 days
    growthDays.push(growthDays[growthDays.length - 1] + gap);
  }
  return growthDays;
}

/** Returning users active on one day are capped at 6. */
const MAX_RETURNING_USERS = 6;

/** Probability that an existing user is active on day `t`. */
function activeProbability(t: number): number {
  if (t < 7) return 0.35;
  return Math.min(0.65, 0.4 + (t - 7) * 0.012);
}

/** Average number of in-app actions per session on day `t`. */
function actionsPerSession(t: number): number {
  if (t < 7) return 2;
  return Math.min(9, 3 + (t - 7) * 0.2);
}

// --- Event building --------------------------------------------------------

const DEVICES = [
  {category: "mobile", operating_system: "Android", browser: "Chrome"},
  {category: "mobile", operating_system: "iOS", browser: "Safari"},
  {category: "desktop", operating_system: "Windows", browser: "Chrome"},
];

const CATEGORIES = ["vegetables", "meat", "dairy", "fruits", "drinks", "dry"];

function userIdFor(n: number): string {
  return `syn_${String(n).padStart(3, "0")}`;
}

function clientIdFor(n: number): string {
  const r = rng(`client-${n}`);
  const a = Math.floor(r() * 1e9);
  const b = 1727481600 + n * 3571; // stable "first seen" style suffix
  return `${a}.${b}`;
}

/** Day on which user `n` (1-based) signs up. */
function joinDayOf(n: number): number {
  let t = 0;
  while (cumulativeUsers(t) < n) t++;
  return t;
}

function pick<T>(r: () => number, items: T[]): T {
  return items[Math.floor(r() * items.length)];
}

function buildSessionEvents(
  r: () => number,
  t: number,
  startMs: number,
  isSignUpSession: boolean
): MpEvent[] {
  const sessionId = Math.floor(startMs / 1000);
  let cursor = startMs;
  const events: MpEvent[] = [];

  const push = (name: string, extra: Record<string, string | number> = {}) => {
    const engagement = 4000 + Math.floor(r() * 40000);
    events.push({
      name,
      timestamp_micros: cursor * 1000,
      params: {
        session_id: sessionId,
        engagement_time_msec: engagement,
        data_source: "synthetic",
        ...extra,
      },
    });
    cursor += engagement + Math.floor(r() * 5000);
  };

  const screen = (name: string) =>
    push("screen_view", {screen_name: name, screen_class: name});

  if (isSignUpSession) {
    screen("auth");
    push("sign_up", {method: r() < 0.6 ? "google" : "email"});
  } else if (r() < 0.15) {
    screen("auth");
    push("login", {method: r() < 0.6 ? "google" : "email"});
  }
  screen("home");

  const target = Math.max(
    1,
    Math.round(actionsPerSession(t) * (0.6 + r() * 0.8))
  );
  for (let i = 0; i < target; i++) {
    const roll = r();
    if (roll < 0.35) {
      screen("inventory");
    } else if (roll < 0.55) {
      screen("itemForm");
      push("inventory_item_added", {
        category_id: pick(r, CATEGORIES),
        source: "manual",
      });
    } else if (roll < 0.75) {
      screen("scan");
      // Early days: OCR fails more often.
      const success = r() < (t < 7 ? 0.6 : 0.85);
      const itemCount = success ? 2 + Math.floor(r() * 8) : 0;
      push("receipt_scanned", {
        success: success ? 1 : 0,
        item_count: itemCount,
      });
      if (success && r() < 0.8) {
        push("receipt_items_confirmed", {item_count: itemCount});
      }
    } else if (roll < 0.88) {
      screen("expirationManagement");
    } else if (roll < 0.96) {
      screen("profile");
    } else {
      // Browses membership but no payment yet.
      screen("myMembership");
    }
  }
  return events;
}

/** Builds every Measurement Protocol payload for one Vietnam calendar day. */
export function planDay(config: SyntheticConfig, date: string): DayPlan {
  const t = dayIndexOf(config, date);
  const dayStart = vnDayStartMs(date);
  const total = cumulativeUsers(t);
  const prevTotal = cumulativeUsers(t - 1);
  const payloads: MpPayload[] = [];
  let sessions = 0;
  let activeUsers = 0;

  // Returning (non-new) users per day are capped at MAX_RETURNING_USERS; pick
  // which ones in a seeded random order so it isn't always the oldest users.
  const order = Array.from({length: prevTotal}, (_, i) => i + 1);
  const shuffle = rng(`${date}-order`);
  for (let i = order.length - 1; i > 0; i--) {
    const j = Math.floor(shuffle() * (i + 1));
    [order[i], order[j]] = [order[j], order[i]];
  }
  const cap = MAX_RETURNING_USERS;
  const returningSlots = new Set<number>();
  for (const n of order) {
    const probe = rng(`${date}-user-${n}`);
    if (probe() <= activeProbability(t)) returningSlots.add(n);
    if (returningSlots.size >= cap) break;
  }

  for (let n = 1; n <= total; n++) {
    const r = rng(`${date}-user-${n}`);
    const isNew = n > prevTotal;
    if (!isNew) {
      if (r() > activeProbability(t)) continue;
      if (returningSlots.has(n) === false) continue;
    }
    activeUsers++;

    const sessionCount = isNew ? 1 : 1 + (r() < Math.min(0.5, t * 0.02) ? 1 : 0);
    const events: MpEvent[] = [];
    for (let s = 0; s < sessionCount; s++) {
      // Sessions between 07:00 and 22:30 Vietnam time.
      const startMs =
        dayStart + 7 * 3600000 + Math.floor(r() * 15.5 * 3600000);
      events.push(...buildSessionEvents(r, t, startMs, isNew && s === 0));
    }
    sessions += sessionCount;

    const device = DEVICES[hashString(`device-${n}`) % DEVICES.length];
    payloads.push({
      client_id: clientIdFor(n),
      user_id: userIdFor(n),
      user_properties: {
        data_source: {value: "synthetic"},
        join_day: {value: addDays(config.startDate, joinDayOf(n))},
      },
      user_location: {
        country_id: "VN",
        region_id: "VN-SG",
        city: "Ho Chi Minh City",
      },
      device: {...device, language: "vi-vn"},
      events: events.sort((a, b) => a.timestamp_micros - b.timestamp_micros),
    });
  }

  return {
    date,
    dayIndex: t,
    totalUsers: total,
    activeUsers,
    newUsers: Math.max(0, total - prevTotal),
    sessions,
    events: payloads.reduce((sum, p) => sum + p.events.length, 0),
    payloads,
  };
}

// --- Sending ---------------------------------------------------------------

export interface SendOptions {
  measurementId: string;
  apiSecret: string;
  /** Use the validation endpoint (nothing is recorded). */
  validateOnly?: boolean;
  /** Events newer than this (epoch ms) are dropped. Defaults to now. */
  nowMs?: number;
}

/**
 * Sends a day's payloads. Events in the future or older than GA4's 72h
 * window are dropped. Returns the number of events actually sent.
 */
export async function sendDay(plan: DayPlan, opts: SendOptions): Promise<number> {
  const now = opts.nowMs ?? Date.now();
  const minMs = now - MAX_BACKFILL_MS;
  const url =
    `${opts.validateOnly ? MP_DEBUG_ENDPOINT : MP_ENDPOINT}` +
    `?measurement_id=${encodeURIComponent(opts.measurementId)}` +
    `&api_secret=${encodeURIComponent(opts.apiSecret)}`;

  let sent = 0;
  for (const payload of plan.payloads) {
    const events = payload.events.filter((e) => {
      const ms = e.timestamp_micros / 1000;
      return ms <= now && ms >= minMs;
    });
    for (let i = 0; i < events.length; i += MAX_EVENTS_PER_REQUEST) {
      const chunk = events.slice(i, i + MAX_EVENTS_PER_REQUEST);
      const body = {
        ...payload,
        // Request-level timestamp = earliest event in the chunk.
        timestamp_micros: chunk[0].timestamp_micros,
        events: chunk,
      };
      const res = await fetch(url, {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        throw new Error(`GA4 MP HTTP ${res.status}: ${await res.text()}`);
      }
      if (opts.validateOnly) {
        const result = (await res.json()) as {validationMessages?: unknown[]};
        if (result.validationMessages?.length) {
          throw new Error(
            `GA4 MP validation: ${JSON.stringify(result.validationMessages)}`
          );
        }
      }
      sent += chunk.length;
    }
  }
  return sent;
}
