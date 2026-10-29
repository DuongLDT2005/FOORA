/**
 * Compresses the seed food photos in seed_images/foods/, uploads them to
 * Firebase Storage (foods/<foodId>.webp) and points each food's photoUrl at
 * the uploaded file, both in seed_foods_and_categories.json and in Firestore.
 *
 * Files must be named after the foodId (e.g. water-spinach.jpg).
 * Foods without a photo in the folder are left unchanged.
 *
 * Usage:
 *   npm run upload:food-images            # dry run, prints what would change
 *   npm run upload:food-images -- --apply # upload and write
 */
import * as crypto from "crypto";
import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let sharp: any;
try { sharp = require("sharp"); } catch {}
import {Collections} from "../constants/collections";

const PROJECT_ID = process.env.GCLOUD_PROJECT || "foora-app";
const BUCKET = `${PROJECT_ID}.firebasestorage.app`;
const IMAGE_WIDTH = 400;
const WEBP_QUALITY = 75;
const SUPPORTED_EXTENSIONS = [".jpg", ".jpeg", ".png", ".webp"];

const apply = process.argv.includes("--apply");

const repoRoot = path.join(__dirname, "../../..");
const imagesDir = path.join(repoRoot, "seed_images/foods");
const seedJsonPath = path.join(
  repoRoot,
  "functions/src/data/seed_foods_and_categories.json",
);

delete process.env.FIRESTORE_EMULATOR_HOST;
delete process.env.FIREBASE_STORAGE_EMULATOR_HOST;

const serviceAccountPath = path.join(repoRoot, "functions/serviceAccountKey.json");
admin.initializeApp({
  credential: fs.existsSync(serviceAccountPath) ?
    admin.credential.cert(JSON.parse(fs.readFileSync(serviceAccountPath, "utf-8"))) :
    admin.credential.applicationDefault(),
  projectId: PROJECT_ID,
  storageBucket: BUCKET,
});

interface SeedFood {
  foodId: string;
  name: string;
  photoUrl: string | null;
}

function publicUrl(objectPath: string, version: string): string {
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/` +
    `${encodeURIComponent(objectPath)}?alt=media&v=${version}`;
}

async function main() {
  const seed = JSON.parse(fs.readFileSync(seedJsonPath, "utf-8"));
  const foods: SeedFood[] = seed.foods;
  const foodsById = new Map(foods.map((f) => [f.foodId, f]));

  const files = fs.existsSync(imagesDir) ?
    fs.readdirSync(imagesDir).filter((f) =>
      SUPPORTED_EXTENSIONS.includes(path.extname(f).toLowerCase())) :
    [];

  const unknown = files.filter((f) => !foodsById.has(path.parse(f).name));
  if (unknown.length > 0) {
    console.warn(`⚠️  ${unknown.length} file(s) do not match any foodId and will be skipped:`);
    unknown.forEach((f) => console.warn(`   - ${f}`));
  }

  const bucket = admin.storage().bucket();
  const db = admin.firestore();
  let totalBytes = 0;
  let uploaded = 0;

  for (const file of files) {
    const foodId = path.parse(file).name;
    const food = foodsById.get(foodId);
    if (!food) continue;

    const webp = await sharp(path.join(imagesDir, file))
      .rotate() // respect EXIF orientation from phone photos
      .resize({width: IMAGE_WIDTH, height: IMAGE_WIDTH, fit: "cover"})
      .webp({quality: WEBP_QUALITY})
      .toBuffer();
    totalBytes += webp.length;

    const objectPath = `foods/${foodId}.webp`;
    // Content hash in the URL so a replaced photo is not served from cache.
    const version = crypto.createHash("sha1").update(webp).digest("hex").slice(0, 10);
    const url = publicUrl(objectPath, version);

    console.log(`${apply ? "⬆️ " : "🔍"} ${foodId.padEnd(28)} ${(webp.length / 1024).toFixed(1).padStart(5)} KB  ${food.name}`);
    if (!apply) continue;

    await bucket.file(objectPath).save(webp, {
      contentType: "image/webp",
      metadata: {cacheControl: "public, max-age=31536000, immutable"},
      resumable: false,
    });
    await db.collection(Collections.FOODS).doc(foodId).set({photoUrl: url}, {merge: true});
    food.photoUrl = url;
    uploaded++;
  }

  if (apply) {
    // Flutter web loads images with fetch, which needs CORS on the bucket.
    await bucket.setCorsConfiguration([
      {origin: ["*"], method: ["GET", "HEAD"], maxAgeSeconds: 3600},
    ]);
    fs.writeFileSync(seedJsonPath, JSON.stringify(seed, null, 2));
  }

  const missing = foods.filter((f) =>
    !files.some((file) => path.parse(file).name === f.foodId));
  console.log(
    `\n${apply ? `✅ Uploaded ${uploaded}` : `Dry run: ${files.length - unknown.length} would be uploaded`}` +
    ` photo(s), ${(totalBytes / 1024 / 1024).toFixed(2)} MB total.`
  );
  console.log(`📋 ${missing.length} food(s) still have no photo in seed_images/foods/.`);
  if (!apply) console.log("Run again with --apply to upload.");
}

main().catch((err) => {
  console.error("❌ Upload failed:", err);
  process.exit(1);
});
