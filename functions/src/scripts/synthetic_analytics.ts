/**
 * Manual runner for the synthetic demo traffic.
 *
 *   npm run analytics:demo -- --preview            # print the growth table
 *   npm run analytics:demo -- --send --validate    # dry-run against GA4 validator
 *   npm run analytics:demo -- --send               # push the last ~72h to GA4
 *   npm run analytics:demo -- --csv <file>         # export events start → now as CSV
 *
 * Reads GA4_DEMO_MEASUREMENT_ID and optional GA4_DEMO_START_DATE from
 * functions/.env, and GA4_DEMO_API_SECRET from functions/.secret.local.
 */
import * as dotenv from "dotenv";
import * as fs from "fs";
import * as path from "path";
import {
  MAX_BACKFILL_MS,
  addDays,
  mockUid,
  planDay,
  sendDay,
  vnDateOf,
  vnDayStartMs,
} from "../analytics/synthetic_traffic";

dotenv.config({path: path.resolve(__dirname, "../../.env")});
// The API secret lives here (not in .env) so deploys don't publish it as a
// plain env var, which clashes with the GA4_DEMO_API_SECRET secret.
dotenv.config({path: path.resolve(__dirname, "../../.secret.local")});

const args = process.argv.slice(2);
const startDate = process.env.GA4_DEMO_START_DATE || "2026-09-28";
const config = {startDate};
const now = Date.now();
const today = vnDateOf(now);

function preview(): void {
  const end = addDays(today, 14);
  console.log("date        day  users  new  active  sessions  events");
  for (let d = startDate; d <= end; d = addDays(d, 1)) {
    const p = planDay(config, d);
    const mark = d === today ? "  <- today" : d > today ? "  (future)" : "";
    console.log(
      `${d}  ${String(p.dayIndex).padStart(3)}  ${String(p.totalUsers).padStart(5)}` +
        `  ${String(p.newUsers).padStart(3)}  ${String(p.activeUsers).padStart(6)}` +
        `  ${String(p.sessions).padStart(8)}  ${String(p.events).padStart(6)}${mark}`
    );
  }
}

async function send(validateOnly: boolean): Promise<void> {
  const measurementId = process.env.GA4_DEMO_MEASUREMENT_ID;
  const apiSecret = process.env.GA4_DEMO_API_SECRET;
  if (!measurementId || !apiSecret) {
    throw new Error("Missing GA4_DEMO_MEASUREMENT_ID (functions/.env) or " +
        "GA4_DEMO_API_SECRET (functions/.secret.local)");
  }

  // Only days that overlap GA4's 72h acceptance window.
  let date = vnDateOf(now - MAX_BACKFILL_MS);
  if (date < startDate) date = startDate;
  for (; vnDayStartMs(date) <= now; date = addDays(date, 1)) {
    const plan = planDay(config, date);
    const sent = await sendDay(plan, {measurementId, apiSecret, validateOnly, nowMs: now});
    console.log(
      `${validateOnly ? "[validate] " : ""}${date}: active=${plan.activeUsers} ` +
        `sessions=${plan.sessions} events sent=${sent}/${plan.events}`
    );
  }
}

function csvCell(value: string | number | undefined): string {
  if (value === undefined) return "";
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, "\"\"")}"` : text;
}

function exportCsv(file: string): void {
  const columns = [
    "timestamp", "event_name", "user_id", "session_id", "screen_name",
    "method", "category_id", "success", "item_count",
    "device_category", "operating_system", "browser", "city", "data_source",
  ];
  const rows: {ms: number; line: string}[] = [];
  for (let d = startDate; vnDayStartMs(d) <= now; d = addDays(d, 1)) {
    for (const payload of planDay(config, d).payloads) {
      for (const e of payload.events) {
        const ms = e.timestamp_micros / 1000;
        if (ms > now) continue;
        const p = e.params;
        // ISO timestamp in Vietnam time (+07:00).
        const local = new Date(ms + 7 * 3600000).toISOString().slice(0, 19);
        const line = [
          `${local}+07:00`, e.name, mockUid(payload.user_id), p.session_id,
          p.screen_name, p.method, p.category_id, p.success, p.item_count,
          payload.device.category, payload.device.operating_system,
          payload.device.browser, payload.user_location.city, p.data_source,
        ].map(csvCell).join(",");
        rows.push({ms, line});
      }
    }
  }
  rows.sort((a, b) => a.ms - b.ms);
  const lines = [columns.join(","), ...rows.map((r) => r.line)];
  // BOM so Excel opens the file as UTF-8.
  fs.writeFileSync(file, "﻿" + lines.join("\n") + "\n", "utf8");
  console.log(`Wrote ${rows.length} events to ${file}`);
}

(async () => {
  const csvIndex = args.indexOf("--csv");
  if (csvIndex >= 0) {
    exportCsv(args[csvIndex + 1] || "foora_events.csv");
  } else if (args.includes("--send")) {
    await send(args.includes("--validate"));
  } else {
    preview();
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
