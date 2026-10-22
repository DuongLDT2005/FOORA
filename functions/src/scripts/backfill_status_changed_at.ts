/**
 * Backfill script: adds `statusChangedAt` to existing inventory_items
 * that were created before the Waste Statistics feature was introduced.
 *
 * Rules applied:
 *   - active items   → statusChangedAt = createdAt
 *   - consumed/discarded items without statusChangedAt → statusChangedAt = updatedAt ?? createdAt
 *
 * Run:
 *   cd functions
 *   npm run build
 *   node lib/scripts/backfill_status_changed_at.js          # emulator
 *   node lib/scripts/backfill_status_changed_at.js --prod   # production
 *
 * Max 400 docs per batch to stay within Firestore limits.
 */

import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";

const isProd = process.argv.includes("--prod");

/** Same lookup as seed_firestore.ts: a service-account key next to functions/. */
function getServiceAccountCredential(): admin.ServiceAccount | null {
  const possiblePaths = [
    path.join(__dirname, "../../serviceAccountKey.json"),
    path.join(process.cwd(), "serviceAccountKey.json"),
    path.join(process.cwd(), "service-account.json"),
  ];
  for (const p of possiblePaths) {
    if (fs.existsSync(p)) {
      console.log(`Using service account key at: ${p}`);
      return JSON.parse(fs.readFileSync(p, "utf-8"));
    }
  }
  return null;
}

if (isProd) {
  // Prefer a service-account key; fall back to Application Default Credentials.
  const serviceAccount = getServiceAccountCredential();
  const projectId = process.env.GCLOUD_PROJECT || "foora-app";
  admin.initializeApp(
    serviceAccount ?
      {credential: admin.credential.cert(serviceAccount), projectId} :
      {projectId},
  );
  console.log(`Running against PRODUCTION Firestore (${projectId}).`);
} else {
  // Point to the local Firestore emulator.
  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
  admin.initializeApp({projectId: "foora-app"});
  console.log("Running against LOCAL emulator at 127.0.0.1:8080");
}

const db = admin.firestore();
const BATCH_SIZE = 400;

async function backfill(): Promise<void> {
  const householdsSnap = await db.collection("households").get();
  console.log(`Found ${householdsSnap.size} household(s).`);

  let totalUpdated = 0;
  let totalSkipped = 0;

  for (const householdDoc of householdsSnap.docs) {
    const householdId = householdDoc.id;
    console.log(`\nProcessing household: ${householdId}`);

    const itemsSnap = await db
      .collection("households")
      .doc(householdId)
      .collection("inventory_items")
      .get();

    console.log(`  Found ${itemsSnap.size} item(s).`);

    const toUpdate: Array<{ref: admin.firestore.DocumentReference; statusChangedAt: admin.firestore.Timestamp}> = [];

    for (const itemDoc of itemsSnap.docs) {
      const data = itemDoc.data();

      // Skip items that already have statusChangedAt.
      if (data.statusChangedAt) {
        totalSkipped++;
        continue;
      }

      const status: string = data.status ?? "active";
      let statusChangedAt: admin.firestore.Timestamp;

      if (status === "consumed" || status === "discarded") {
        // Use updatedAt as best approximation; fall back to createdAt.
        statusChangedAt =
          (data.updatedAt as admin.firestore.Timestamp | undefined) ??
          (data.createdAt as admin.firestore.Timestamp | undefined) ??
          admin.firestore.Timestamp.now();
      } else {
        // Active items: use createdAt as the initial statusChangedAt.
        statusChangedAt =
          (data.createdAt as admin.firestore.Timestamp | undefined) ??
          admin.firestore.Timestamp.now();
      }

      toUpdate.push({ref: itemDoc.ref, statusChangedAt});
    }

    // Write in batches of up to BATCH_SIZE documents.
    for (let i = 0; i < toUpdate.length; i += BATCH_SIZE) {
      const slice = toUpdate.slice(i, i + BATCH_SIZE);
      const batch = db.batch();
      for (const {ref, statusChangedAt} of slice) {
        batch.update(ref, {statusChangedAt});
      }
      await batch.commit();
      console.log(`  Committed batch ${Math.floor(i / BATCH_SIZE) + 1}: ${slice.length} docs`);
      totalUpdated += slice.length;
    }
  }

  console.log("\n✅ Backfill complete.");
  console.log(`   Updated : ${totalUpdated}`);
  console.log(`   Skipped : ${totalSkipped} (already had statusChangedAt)`);
  console.log("\n⚠️  Note: statusChangedAt for old data is approximated from updatedAt.");
  console.log("   Statistics before this backfill date are indicative only.");
}

backfill().catch((err) => {
  console.error("Backfill failed:", err);
  process.exit(1);
});
