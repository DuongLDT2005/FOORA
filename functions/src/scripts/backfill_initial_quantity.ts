import * as admin from "firebase-admin";
import {FieldPath, FieldValue} from "firebase-admin/firestore";
import {inferInitialQuantity} from "../inventory/services/initial_quantity";

// Deliberately emulator-only. Production requires an approved migration runbook.
process.env.FIRESTORE_EMULATOR_HOST ||= "127.0.0.1:8080";
process.env.GCLOUD_PROJECT ||= "foora-app";
if (!admin.apps.length) admin.initializeApp({projectId: process.env.GCLOUD_PROJECT});
const firestore = admin.firestore();
const apply = process.argv.includes("--apply");

async function run(): Promise<void> {
  if (!process.env.FIRESTORE_EMULATOR_HOST ||
      process.argv.includes("--prod")) {
    throw new Error("Backfill này chỉ chạy trên Firestore Emulator.");
  }
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let scanned = 0;
  let inferred = 0;
  let reset = 0;
  let skipped = 0;
  let anomalous = 0;
  for (;;) {
    let query = firestore.collectionGroup("inventory_items")
      .orderBy(FieldPath.documentId()).limit(200);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;
    const batch = firestore.batch();
    let writes = 0;
    for (const doc of snapshot.docs) {
      scanned++;
      const data = doc.data();
      if (typeof data.initialQuantity === "number" &&
          Number.isFinite(data.initialQuantity) && data.initialQuantity > 0) {
        skipped++;
        continue;
      }
      const result = inferInitialQuantity(data.quantity, data.remainingPercentage);
      if (!result || (data.status === "active" && data.quantity === 0)) {
        anomalous++;
        continue;
      }
      if (result.source === "inferred") inferred++;
      else reset++;
      if (apply) {
        batch.update(doc.ref, {
          initialQuantity: result.initialQuantity,
          remainingPercentage: result.remainingPercentage,
          initialQuantityMigration: result.source,
          updatedAt: FieldValue.serverTimestamp(),
        });
        writes++;
      }
    }
    if (writes > 0) await batch.commit();
    cursor = snapshot.docs[snapshot.docs.length - 1];
  }
  console.info(JSON.stringify({mode: apply ? "apply" : "dry-run",
    scanned, inferred, reset, skipped, anomalous}));
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
