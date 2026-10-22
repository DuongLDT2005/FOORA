/**
 * Seeds mock users into Firebase Auth + Firestore from the same synthetic
 * model used for the demo GA4 traffic (same UIDs, sign-up times and scans).
 *
 *   npm run seed:mock               # Auth + Firestore emulators
 *   npm run seed:mock -- --prod     # production project (needs credentials)
 *   npm run seed:mock -- --clean    # delete every mock user (add --prod for prod)
 *
 * Every Firestore doc it writes carries `isMock: true`, and every Auth user
 * gets the custom claim `mock: true`, so they can always be found and removed.
 * Re-running is safe: all ids are deterministic and documents are overwritten.
 */
import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";
import {Collections} from "../constants/collections";
import {
  addDays,
  mockId,
  mockUid,
  planDay,
  vnDateOf,
  vnDayStartMs,
} from "../analytics/synthetic_traffic";

const args = process.argv.slice(2);
const isProd = args.includes("--prod");
const isClean = args.includes("--clean");
const START_DATE = process.env.GA4_DEMO_START_DATE || "2026-09-28";

if (!isProd) {
  process.env.FIRESTORE_EMULATOR_HOST ||= "localhost:8080";
  process.env.FIREBASE_AUTH_EMULATOR_HOST ||= "localhost:9099";
} else {
  delete process.env.FIRESTORE_EMULATOR_HOST;
  delete process.env.FIREBASE_AUTH_EMULATOR_HOST;
}
process.env.GCLOUD_PROJECT ||= "foora-app";

function serviceAccount(): admin.ServiceAccount | null {
  const candidates = [
    path.join(__dirname, "../../serviceAccountKey.json"),
    path.join(process.cwd(), "serviceAccountKey.json"),
    path.join(process.cwd(), "service-account.json"),
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return JSON.parse(fs.readFileSync(p, "utf-8"));
  }
  return null;
}

if (admin.apps.length === 0) {
  const credential = isProd ? serviceAccount() : null;
  admin.initializeApp({
    ...(credential ? {credential: admin.credential.cert(credential)} : {}),
    projectId: process.env.GCLOUD_PROJECT,
  });
}

const db = admin.firestore();
const auth = admin.auth();
const {Timestamp} = admin.firestore;

// --- Realistic profile data -------------------------------------------------

const FAMILY = ["Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Huỳnh", "Phan", "Võ", "Đặng", "Bùi", "Đỗ", "Ngô"];
const NAMES = {
  female: {
    middle: ["Thị", "Ngọc", "Thu", "Phương", "Thanh", "Hoài", "Minh"],
    given: ["Anh", "Châu", "Giang", "Hà", "Hân", "Hoa", "Linh", "Mai", "My", "Ngân",
      "Nhi", "Quỳnh", "Thảo", "Trang", "Trâm", "Vy", "Yến", "Tâm"],
  },
  male: {
    middle: ["Văn", "Minh", "Đức", "Gia", "Quốc", "Thanh", "Hoàng"],
    given: ["An", "Bảo", "Duy", "Hiếu", "Huy", "Khánh", "Khoa", "Long", "Nam",
      "Phúc", "Quân", "Tú", "Tuấn", "Thịnh"],
  },
};

function seeded(seed: string): () => number {
  let i = 0;
  return () => {
    const hex = mockId(`${seed}-${i++}`, 8);
    let h = 0;
    for (const c of hex) h = (h * 62 + c.charCodeAt(0)) % 1_000_003;
    return h / 1_000_003;
  };
}

function stripDiacritics(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D");
}

interface Profile {
  fullName: string;
  email: string;
}

function profileFor(syntheticId: string): Profile {
  const r = seeded(`profile-${syntheticId}`);
  const pick = <T>(items: T[]) => items[Math.floor(r() * items.length)];
  const names = r() < 0.6 ? NAMES.female : NAMES.male;
  const family = pick(FAMILY);
  const middle = pick(names.middle);
  const given = pick(names.given);
  const g = stripDiacritics(given).toLowerCase();
  const f = stripDiacritics(family).toLowerCase();
  const yy = String(1996 + Math.floor(r() * 9)).slice(-2); // born 1996–2004
  const styles = [
    `${g}.${f}${yy}`,
    `${g}${f}${yy}${Math.floor(r() * 90 + 10)}`,
    `${f}${g}.${Math.floor(r() * 900 + 100)}`,
  ];
  return {
    fullName: `${family} ${middle} ${given}`,
    email: `${pick(styles)}@gmail.com`,
  };
}

// --- Food catalog -------------------------------------------------------------

interface Food {
  foodId: string;
  name: string;
  normalizedName: string;
  categoryId: string;
  defaultUnit: string;
  photoUrl?: string;
}

interface Category {
  categoryId: string;
  defaultShelfLife?: {fridge?: {minValue: number | null; maxValue: number | null}};
}

const catalog = JSON.parse(
  fs.readFileSync(path.join(__dirname, "../../src/data/seed_foods_and_categories.json"), "utf-8")
) as {foods: Food[]; food_categories: Category[]};
const foods = catalog.foods;
const shelfLife = new Map(
  catalog.food_categories.map((c) => [c.categoryId, c.defaultShelfLife?.fridge?.maxValue ?? 7])
);

const FREE_FOOD_LIMIT = 30;
const FREE_SCAN_QUOTA = 5;
const DAY_MS = 24 * 3600 * 1000;

// --- Build mock state from the synthetic event stream ---------------------------

interface ItemDraft {
  id: string;
  food: Food;
  quantity: number;
  source: "manual" | "receipt_scan";
  storageLocationId: string;
  at: number;
}

interface ReceiptDraft {
  id: string;
  at: number;
  detected: number;
  confirmed: boolean;
  itemIds: string[];
}

interface UserDraft {
  syntheticId: string;
  uid: string;
  profile: Profile;
  provider: "google" | "email";
  createdAt: number;
  lastActiveAt: number;
  items: ItemDraft[];
  receipts: ReceiptDraft[];
  scansByMonth: Map<string, number>;
}

function newItem(seed: string, at: number, source: ItemDraft["source"]): ItemDraft {
  const r = seeded(seed);
  const food = foods[Math.floor(r() * foods.length)];
  const unit = food.defaultUnit;
  const quantity = unit === "kg" ? Math.round((0.3 + r() * 1.2) * 10) / 10 : 1 + Math.floor(r() * 4);
  return {
    id: mockId(`item-${seed}`),
    food,
    quantity,
    source,
    storageLocationId: food.categoryId === "frozen_foods" || r() < 0.15 ? "freezer" : "fridge",
    at,
  };
}

function buildUsers(): UserDraft[] {
  const users = new Map<string, UserDraft>();
  const now = Date.now();

  for (let d = START_DATE; vnDayStartMs(d) <= now; d = addDays(d, 1)) {
    for (const payload of planDay({startDate: START_DATE}, d).payloads) {
      let user = users.get(payload.user_id);
      for (const e of payload.events) {
        const at = e.timestamp_micros / 1000;
        if (at > now) continue;
        const key = `${payload.user_id}-${e.timestamp_micros}`;

        if (!user) {
          const signUp = payload.events.find((x) => x.name === "sign_up");
          user = {
            syntheticId: payload.user_id,
            uid: mockUid(payload.user_id),
            profile: profileFor(payload.user_id),
            provider: signUp?.params.method === "google" ? "google" : "email",
            createdAt: at,
            lastActiveAt: at,
            items: [],
            receipts: [],
            scansByMonth: new Map(),
          };
          users.set(payload.user_id, user);
        }
        user.lastActiveAt = at;

        if (e.name === "inventory_item_added") {
          user.items.push(newItem(key, at, "manual"));
        } else if (e.name === "receipt_scanned" && e.params.success === 1) {
          // Free plan: quota blocks scans beyond 5/month, so no receipt is created.
          const month = vnDateOf(at).slice(0, 7);
          const used = user.scansByMonth.get(month) ?? 0;
          if (used >= FREE_SCAN_QUOTA) continue;
          user.scansByMonth.set(month, used + 1);
          user.receipts.push({
            id: mockId(`receipt-${key}`),
            at,
            detected: Number(e.params.item_count) || 1,
            confirmed: false,
            itemIds: [],
          });
        } else if (e.name === "receipt_items_confirmed") {
          const receipt = user.receipts[user.receipts.length - 1];
          if (!receipt || receipt.confirmed) continue;
          receipt.confirmed = true;
          for (let i = 0; i < receipt.detected; i++) {
            const item = newItem(`${key}-${i}`, at, "receipt_scan");
            user.items.push(item);
            receipt.itemIds.push(item.id);
          }
        }
      }
    }
  }
  return [...users.values()];
}

/** Older / expired items get used up; keeps active items under the free limit. */
function itemStatus(item: ItemDraft, expiresAt: number, activeSoFar: number): string {
  const now = Date.now();
  const r = seeded(`status-${item.id}`);
  if (expiresAt < now) return r() < 0.8 ? "consumed" : "discarded";
  if (now - item.at > 3 * DAY_MS && r() < 0.35) return "consumed";
  if (activeSoFar >= FREE_FOOD_LIMIT) return "consumed";
  return "active";
}

// --- Writers -----------------------------------------------------------------------

async function writeAuthUsers(users: UserDraft[]): Promise<void> {
  // importUsers lets us set realistic creation / last sign-in times.
  const records: admin.auth.UserImportRecord[] = users.map((u) => ({
    uid: u.uid,
    email: u.profile.email,
    emailVerified: true,
    displayName: u.profile.fullName,
    customClaims: {mock: true},
    metadata: {
      creationTime: new Date(u.createdAt).toUTCString(),
      lastSignInTime: new Date(u.lastActiveAt).toUTCString(),
    },
    providerData:
      u.provider === "google" ?
        [{
          uid: mockId(`google-${u.uid}`, 21).replace(/\D/g, "7").padEnd(21, "1"),
          email: u.profile.email,
          displayName: u.profile.fullName,
          providerId: "google.com",
        }] :
        [],
  }));
  const result = await auth.importUsers(records);
  for (const err of result.errors) {
    console.error(`   ❌ Auth import ${records[err.index].email}: ${err.error.message}`);
  }
  console.log(`🔐 Auth: imported ${result.successCount}/${records.length} users`);
}

async function writeFirestore(users: UserDraft[]): Promise<void> {
  const writer = db.bulkWriter();
  const ts = (ms: number) => Timestamp.fromMillis(ms);
  const currentMonth = vnDateOf(Date.now()).slice(0, 7);
  let itemCount = 0;

  for (const u of users) {
    const householdId = mockId(`household-${u.uid}`);
    const userRef = db.collection(Collections.USERS).doc(u.uid);
    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);

    let active = 0;
    const sorted = [...u.items].sort((a, b) => b.at - a.at); // newest first
    for (const item of sorted) {
      const days = shelfLife.get(item.food.categoryId) ?? 7;
      const expiresAt = item.at + (item.storageLocationId === "freezer" ? days * 6 : days) * DAY_MS;
      const status = itemStatus(item, expiresAt, active);
      if (status === "active") active++;
      const updatedAt = status === "active" ? item.at : Math.min(Date.now(), expiresAt - DAY_MS / 2);
      writer.set(householdRef.collection(Collections.INVENTORY_ITEMS).doc(item.id), {
        foodId: item.food.foodId,
        name: item.food.name,
        normalizedName: item.food.normalizedName,
        categoryId: item.food.categoryId,
        quantity: item.quantity,
        unit: item.food.defaultUnit,
        remainingPercentage: status === "active" ? 100 : 0,
        storageLocationId: item.storageLocationId,
        purchaseDate: ts(item.at),
        expirationDate: ts(expiresAt),
        photoUrl: item.food.photoUrl ?? null,
        source: item.source,
        status,
        createdAt: ts(item.at),
        updatedAt: ts(Math.max(item.at, updatedAt)),
        isMock: true,
      });
      itemCount++;
    }

    writer.set(householdRef, {
      name: `Tủ lạnh của ${u.profile.fullName}`,
      ownerId: u.uid,
      members: [u.uid],
      activeItemCount: active,
      createdAt: ts(u.createdAt),
      updatedAt: ts(u.lastActiveAt),
      isMock: true,
    });

    writer.set(userRef, {
      email: u.profile.email,
      fullName: u.profile.fullName,
      role: "member",
      membershipId: "free",
      activeHouseholdId: householdId,
      isActive: true,
      createdAt: ts(u.createdAt),
      updatedAt: ts(u.lastActiveAt),
      isMock: true,
    });

    writer.set(userRef.collection(Collections.AI_USAGE).doc(Collections.AI_USAGE_CURRENT_DOC), {
      period: currentMonth,
      receiptScanUsed: u.scansByMonth.get(currentMonth) ?? 0,
      updatedAt: ts(u.lastActiveAt),
      isMock: true,
    });

    for (const receipt of u.receipts) {
      const receiptRef = userRef.collection(Collections.RECEIPTS).doc(receipt.id);
      writer.set(receiptRef, {
        receiptId: receipt.id,
        householdId,
        imageUrl: null,
        status: receipt.confirmed ? "completed" : "processing",
        processedBy: "gemini-3.6-flash",
        totalItemsDetected: receipt.detected,
        ...(receipt.confirmed ? {confirmedItemsCount: receipt.itemIds.length} : {}),
        createdAt: ts(receipt.at),
        updatedAt: ts(receipt.at + 60_000),
        isMock: true,
      });
      for (const itemId of receipt.itemIds) {
        const item = u.items.find((i) => i.id === itemId);
        if (!item) continue;
        const itemRef = receiptRef.collection(Collections.RECEIPT_ITEMS).doc(mockId(`ri-${itemId}`));
        writer.set(itemRef, {
          receiptItemId: itemRef.id,
          inventoryItemId: itemId,
          rawName: item.food.name.toUpperCase(),
          normalizedName: item.food.normalizedName,
          foodId: item.food.foodId,
          categoryId: item.food.categoryId,
          quantity: item.quantity,
          unit: item.food.defaultUnit,
          storageLocationId: item.storageLocationId,
          confidence: 1.0,
          createdAt: ts(receipt.at + 60_000),
          isMock: true,
        });
      }
    }
  }

  await writer.close();
  console.log(
    `🗂️  Firestore: ${users.length} users/households, ${itemCount} inventory items, ` +
      `${users.reduce((s, u) => s + u.receipts.length, 0)} receipts`
  );
}

async function clean(): Promise<void> {
  const snap = await db.collection(Collections.USERS).where("isMock", "==", true).get();
  const uids: string[] = [];
  for (const doc of snap.docs) {
    uids.push(doc.id);
    const householdId = doc.get("activeHouseholdId") as string | undefined;
    if (householdId) await db.recursiveDelete(db.collection(Collections.HOUSEHOLDS).doc(householdId));
    await db.recursiveDelete(doc.ref);
  }
  if (uids.length) {
    const result = await auth.deleteUsers(uids);
    console.log(`🔐 Auth: deleted ${result.successCount}/${uids.length} users`);
  }
  console.log(`🧹 Removed ${uids.length} mock users and their data`);
}

(async () => {
  console.log(`🎯 Target: ${isProd ? "PRODUCTION (foora-app)" : "emulators"}`);
  if (isClean) {
    await clean();
    return;
  }
  const users = buildUsers();
  // Firestore first: the onUserCreated trigger skips users that already have
  // an activeHouseholdId, so it won't overwrite the backdated profile.
  await writeFirestore(users);
  await writeAuthUsers(users);
  for (const u of users) {
    console.log(
      `   ${u.profile.fullName.padEnd(24)} ${u.profile.email.padEnd(30)} ` +
        `joined ${vnDateOf(u.createdAt)}  items=${u.items.length} receipts=${u.receipts.length}`
    );
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
