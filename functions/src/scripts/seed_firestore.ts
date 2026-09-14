import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";
import {Collections} from "../constants/collections";

const isProd =
  process.argv.includes("--prod") ||
  process.env.NODE_ENV === "production" ||
  process.env.SEED_TARGET === "prod";

if (!isProd) {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    process.env.FIRESTORE_EMULATOR_HOST = "localhost:8080";
  }
} else {
  delete process.env.FIRESTORE_EMULATOR_HOST;
}

if (!process.env.GCLOUD_PROJECT) {
  process.env.GCLOUD_PROJECT = "foora-app";
}

// Find service account key file if available
function getServiceAccountCredential(): admin.ServiceAccount | null {
  const possiblePaths = [
    path.join(__dirname, "../serviceAccountKey.json"),
    path.join(__dirname, "../../serviceAccountKey.json"),
    path.join(process.cwd(), "serviceAccountKey.json"),
    path.join(process.cwd(), "service-account.json"),
  ];

  for (const p of possiblePaths) {
    if (fs.existsSync(p)) {
      console.log(`🔑 [Seed] Found Service Account key at: ${p}`);
      return JSON.parse(fs.readFileSync(p, "utf-8"));
    }
  }
  return null;
}

if (admin.apps.length === 0) {
  const serviceAccount = isProd ? getServiceAccountCredential() : null;
  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.projectId || process.env.GCLOUD_PROJECT || "foora-app",
    });
  } else {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT || "foora-app",
    });
  }
}

const db = admin.firestore();

interface CategoryData {
  categoryId: string;
  name: string;
  code: string;
  icon: string;
  defaultShelfLife?: {
    fridge?: {minValue: number | null; maxValue: number | null; unit: string | null};
    freezer?: {minValue: number | null; maxValue: number | null; unit: string | null};
  };
  isActive: boolean;
}

interface FoodData {
  foodId: string;
  name: string;
  normalizedName: string;
  categoryId: string;
  defaultUnit: string;
  aliases: string[];
  photoUrl: string;
  isActive: boolean;
}

interface SeedDataFile {
  food_categories: CategoryData[];
  foods: FoodData[];
}

export async function seedFirestore() {
  if (isProd) {
    console.log(
      `🚀 [Seed] Running against REAL FIRESTORE in project: "${process.env.GCLOUD_PROJECT || "foora-app"}"`
    );
  } else {
    console.log(
      `ℹ️ [Seed] Connected to Firestore Emulator at ${process.env.FIRESTORE_EMULATOR_HOST}`
    );
  }

  console.log("🌱 [Seed] Starting Master Data seeding into Firestore...");

  let jsonFilePath = path.join(
    __dirname,
    "../../src/data/seed_foods_and_categories.json"
  );
  if (!fs.existsSync(jsonFilePath)) {
    jsonFilePath = path.join(__dirname, "../data/seed_foods_and_categories.json");
  }
  if (!fs.existsSync(jsonFilePath)) {
    throw new Error(`Seed data file not found at: ${jsonFilePath}`);
  }

  const rawData = fs.readFileSync(jsonFilePath, "utf-8");
  const data: SeedDataFile = JSON.parse(rawData);

  // 1. Seed food_categories
  console.log(
    `📦 [Seed] Seeding ${data.food_categories.length} categories (food_categories)...`
  );
  const catBatch = db.batch();
  for (const cat of data.food_categories) {
    const docRef = db.collection(Collections.FOOD_CATEGORIES).doc(cat.categoryId);
    catBatch.set(
      docRef,
      {
        name: cat.name,
        code: cat.code,
        icon: cat.icon,
        defaultShelfLife: cat.defaultShelfLife ?? null,
        isActive: cat.isActive,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
  }
  await catBatch.commit();
  console.log("✅ [Seed] Successfully seeded all food_categories!");

  // 2. Seed foods
  console.log(`🍲 [Seed] Seeding ${data.foods.length} items (foods)...`);
  const foodBatch = db.batch();
  for (const food of data.foods) {
    const docRef = db.collection(Collections.FOODS).doc(food.foodId);
    foodBatch.set(
      docRef,
      {
        name: food.name,
        normalizedName: food.normalizedName,
        categoryId: food.categoryId,
        defaultUnit: food.defaultUnit,
        aliases: food.aliases,
        photoUrl: food.photoUrl,
        isActive: food.isActive,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
  }
  await foodBatch.commit();
  console.log("✅ [Seed] Successfully seeded all foods!");

  // 3. Seed Master Storage Locations (fridge, freezer)
  console.log("❄️ [Seed] Seeding Master Storage Locations (Fridge, Freezer)...");
  const locBatch = db.batch();
  const fridgeRef = db.collection(Collections.STORAGE_LOCATIONS).doc("fridge");
  locBatch.set(
    fridgeRef,
    {
      name: "Ngăn mát",
      code: "FRIDGE",
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true}
  );

  const freezerRef = db.collection(Collections.STORAGE_LOCATIONS).doc("freezer");
  locBatch.set(
    freezerRef,
    {
      name: "Ngăn đông",
      code: "FREEZER",
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true}
  );
  await locBatch.commit();
  console.log("✅ [Seed] Successfully seeded Master Storage Locations!");

  // 4. Seed MVP Memberships (free, premium)
  console.log("👑 [Seed] Seeding Master Memberships (Free, Premium)...");
  const memBatch = db.batch();
  const freeRef = db.collection(Collections.MEMBERSHIPS).doc("free");
  memBatch.set(
    freeRef,
    {
      name: "Free",
      price: 0,
      currency: "VND",
      durationDays: 0,
      foodLimit: 30,
      receiptScanQuota: 5,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true}
  );

  const premRef = db.collection(Collections.MEMBERSHIPS).doc("premium");
  memBatch.set(
    premRef,
    {
      name: "Premium",
      price: 49000,
      currency: "VND",
      durationDays: 30,
      foodLimit: null, // Unlimited items
      receiptScanQuota: null,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true}
  );
  await memBatch.commit();
  console.log("✅ [Seed] Successfully seeded Master Memberships!");

  // 5. Seed shelf_life_rules
  let shelfLifeRulesPath = path.join(
    __dirname,
    "../../src/data/seed_shelf_life_rules.json"
  );
  if (!fs.existsSync(shelfLifeRulesPath)) {
    shelfLifeRulesPath = path.join(
      __dirname,
      "../data/seed_shelf_life_rules.json"
    );
  }
  if (fs.existsSync(shelfLifeRulesPath)) {
    const rulesRaw = fs.readFileSync(shelfLifeRulesPath, "utf-8");
    const rulesData = JSON.parse(rulesRaw);
    const rulesList = rulesData.shelf_life_rules || [];
    console.log(
      `⏱️ [Seed] Seeding ${rulesList.length} rules (shelf_life_rules)...`
    );

    const BATCH_SIZE = 400;
    for (let i = 0; i < rulesList.length; i += BATCH_SIZE) {
      const chunk = rulesList.slice(i, i + BATCH_SIZE);
      const ruleBatch = db.batch();
      for (const rule of chunk) {
        const docRef = db.collection(Collections.SHELF_LIFE_RULES).doc(rule.ruleId);
        ruleBatch.set(
          docRef,
          {
            foodId: rule.foodId,
            foodName: rule.foodName,
            categoryId: rule.categoryId,
            storageLocationId: rule.storageLocationId,
            storageLocationName: rule.storageLocationName,
            minValue: rule.minValue ?? null,
            maxValue: rule.maxValue ?? null,
            unit: rule.unit ?? null,
            isActive: rule.isActive ?? true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true}
        );
      }
      await ruleBatch.commit();
      const upper = Math.min(i + BATCH_SIZE, rulesList.length);
      console.log(`   -> Seeded rules batch ${i + 1} - ${upper}`);
    }
    console.log("✅ [Seed] Successfully seeded all shelf_life_rules!");
  }

  // 6. Seed Sample/Core Users (Admin, Free User, Premium User)
  console.log("👥 [Seed] Seeding sample users (Admin, Free, Premium)...");
  await seedUsers();

  console.log("🎉 [Seed] Master Data and Users seeding completed successfully!");
}

interface SeedUserConfig {
  email: string;
  password: string;
  fullName: string;
  role: "admin" | "member";
  membershipId?: "free" | "premium";
}

async function seedUsers() {
  const usersToSeed: SeedUserConfig[] = [
    {
      email: "foora.team@gmail.com",
      password: "Password@123",
      fullName: "Foora Admin",
      role: "admin",
    },
    {
      email: "user.free@gmail.com",
      password: "Password@123",
      fullName: "User Free",
      role: "member",
      membershipId: "free",
    },
    {
      email: "user.premium@gmail.com",
      password: "Password@123",
      fullName: "User Premium",
      role: "member",
      membershipId: "premium",
    },
  ];

  const now = new Date();
  const period = now.toISOString().slice(0, 7); // Format: "YYYY-MM"
  const serverTimestamp = admin.firestore.FieldValue.serverTimestamp();

  for (const config of usersToSeed) {
    let userRecord: admin.auth.UserRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(config.email);
      console.log(`   ℹ️ Auth user already exists: ${config.email} (UID: ${userRecord.uid})`);
    } catch (error: unknown) {
      const authError = error as {code?: string};
      if (authError.code === "auth/user-not-found") {
        userRecord = await admin.auth().createUser({
          email: config.email,
          emailVerified: true,
          password: config.password,
          displayName: config.fullName,
        });
        console.log(`   ➕ Created Auth user: ${config.email} (UID: ${userRecord.uid})`);
      } else {
        throw error;
      }
    }

    const uid = userRecord.uid;
    const userRef = db.collection(Collections.USERS).doc(uid);
    const userDoc = await userRef.get();

    if (config.role === "admin") {
      // 1. If admin previously had a household, clean it up
      const oldHouseholdId = userDoc.data()?.activeHouseholdId;
      if (oldHouseholdId) {
        await db.collection(Collections.HOUSEHOLDS).doc(oldHouseholdId).delete();
      }

      // 2. Clean up any admin subscriptions or ai_usage
      const aiUsageRef = userRef
        .collection(Collections.AI_USAGE)
        .doc(Collections.AI_USAGE_CURRENT_DOC);
      await aiUsageRef.delete().catch(() => {});

      const subRef = userRef.collection(Collections.SUBSCRIPTIONS).doc("active_sub");
      await subRef.delete().catch(() => {});

      // 3. Set pure Admin user document: NO membershipId, NO activeHouseholdId
      await userRef.set(
        {
          email: config.email,
          fullName: config.fullName,
          role: "admin",
          membershipId: admin.firestore.FieldValue.delete(),
          activeHouseholdId: admin.firestore.FieldValue.delete(),
          isActive: true,
          createdAt: userDoc.exists ? (userDoc.data()?.createdAt ?? serverTimestamp) : serverTimestamp,
          updatedAt: serverTimestamp,
        },
        {merge: true}
      );

      console.log(`   ✅ Seeded pure Admin profile for: ${config.email} (Role: admin, no membership/household/ai_usage/subscriptions)`);
      continue;
    }

    // --- Regular Member (Free / Premium) ---
    let householdId = userDoc.data()?.activeHouseholdId;

    // Create or find default household
    if (!householdId) {
      const householdRef = db.collection(Collections.HOUSEHOLDS).doc();
      householdId = householdRef.id;
      await householdRef.set({
        name: `Tủ lạnh của ${config.fullName}`,
        ownerId: uid,
        members: [uid],
        activeItemCount: 0,
        createdAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });
    }

    // Set or update user document
    await userRef.set(
      {
        email: config.email,
        fullName: config.fullName,
        role: config.role,
        membershipId: config.membershipId ?? "free",
        activeHouseholdId: householdId,
        isActive: true,
        createdAt: userDoc.exists ? (userDoc.data()?.createdAt ?? serverTimestamp) : serverTimestamp,
        updatedAt: serverTimestamp,
      },
      {merge: true}
    );

    // AI usage subcollection
    const aiUsageRef = userRef
      .collection(Collections.AI_USAGE)
      .doc(Collections.AI_USAGE_CURRENT_DOC);
    await aiUsageRef.set(
      {
        period: period,
        receiptScanUsed: 0,
        updatedAt: serverTimestamp,
      },
      {merge: true}
    );

    // If premium, also seed an active subscription
    if (config.membershipId === "premium") {
      const subRef = userRef.collection(Collections.SUBSCRIPTIONS).doc("active_sub");
      const startDate = new Date();
      const endDate = new Date(startDate.getTime() + 30 * 24 * 60 * 60 * 1000); // +30 days

      await subRef.set(
        {
          membershipId: "premium",
          status: "active",
          startDate: admin.firestore.Timestamp.fromDate(startDate),
          endDate: admin.firestore.Timestamp.fromDate(endDate),
          autoRenew: true,
          cancelAtPeriodEnd: false,
          platform: "google_play",
          productId: "foora_premium_monthly",
          purchaseToken: `seed_token_${uid}`,
          createdAt: serverTimestamp,
          updatedAt: serverTimestamp,
        },
        {merge: true}
      );
    }

    console.log(`   ✅ Seeded Firestore profile for: ${config.email} (Role: ${config.role}, Membership: ${config.membershipId})`);
  }
}


// Execute if run directly via CLI
if (require.main === module) {
  seedFirestore()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("❌ [Seed] Failed:", err);
      process.exit(1);
    });
}
