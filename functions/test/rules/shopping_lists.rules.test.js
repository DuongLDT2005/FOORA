/**
 * Firestore security-rules tests for shopping lists/items and the user's
 * notificationSettings. Run with `npm run test:rules`.
 */
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const HOUSEHOLD_ID = "home-1";
const MEMBER_UID = "member-1";
const OUTSIDER_UID = "outsider-1";
const LIST_PATH = `households/${HOUSEHOLD_ID}/shopping_lists/list-1`;
const ITEM_PATH = `${LIST_PATH}/items/item-1`;

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-foora-rules",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "../../../firestore.rules"), "utf8"),
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "households", HOUSEHOLD_ID), {
      name: "Nhà",
      ownerId: MEMBER_UID,
      members: [MEMBER_UID],
      activeItemCount: 0,
    });
    await setDoc(doc(db, "users", MEMBER_UID), {fullName: "A", role: "member"});
    await setDoc(doc(db, LIST_PATH), {name: "Đi chợ", createdBy: MEMBER_UID});
    await setDoc(doc(db, ITEM_PATH), {
      ...newItem(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });
});

function dbAs(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function newItem(overrides = {}) {
  return {
    name: "Sữa tươi",
    normalizedName: "sua tuoi",
    foodId: null,
    categoryId: "dairy",
    quantity: 2,
    unit: "hộp",
    note: null,
    source: "manual",
    isPurchased: false,
    purchasedBy: null,
    purchasedAt: null,
    isAddedToInventory: false,
    inventoryItemId: null,
    addedToInventoryAt: null,
    addedBy: MEMBER_UID,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

test("members read lists; outsiders cannot", async () => {
  await assertSucceeds(getDoc(doc(dbAs(MEMBER_UID), LIST_PATH)));
  await assertFails(getDoc(doc(dbAs(OUTSIDER_UID), LIST_PATH)));
  await assertFails(getDoc(doc(dbAs(OUTSIDER_UID), ITEM_PATH)));
});

test("members create lists with valid fields only", async () => {
  const db = dbAs(MEMBER_UID);
  const base = {
    name: "Cuối tuần",
    createdBy: MEMBER_UID,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(db, `households/${HOUSEHOLD_ID}/shopping_lists/l2`), base));
  await assertFails(setDoc(doc(db, `households/${HOUSEHOLD_ID}/shopping_lists/l3`), {
    ...base, createdBy: OUTSIDER_UID,
  }));
  await assertFails(setDoc(doc(db, `households/${HOUSEHOLD_ID}/shopping_lists/l4`), {
    ...base, status: "completed",
  }));
  await assertFails(deleteDoc(doc(db, LIST_PATH)));
});

test("members add items; inventory fields cannot be forged", async () => {
  const db = dbAs(MEMBER_UID);
  const itemPath = `${LIST_PATH}/items/item-2`;
  await assertSucceeds(setDoc(doc(db, itemPath), newItem()));
  await assertFails(setDoc(doc(db, `${LIST_PATH}/items/item-3`), newItem({
    isAddedToInventory: true,
  })));
  await assertFails(setDoc(doc(db, `${LIST_PATH}/items/item-4`), newItem({quantity: 0})));
  await assertFails(setDoc(doc(db, `${LIST_PATH}/items/item-5`), newItem({source: "hack"})));
  await assertFails(setDoc(
    doc(db, `households/${HOUSEHOLD_ID}/shopping_lists/missing/items/x`),
    newItem()
  ));
  await assertFails(setDoc(doc(dbAs(OUTSIDER_UID), `${LIST_PATH}/items/item-6`), newItem({
    addedBy: OUTSIDER_UID,
  })));
});

test("members tick items but cannot mark them imported", async () => {
  const db = dbAs(MEMBER_UID);
  await assertSucceeds(updateDoc(doc(db, ITEM_PATH), {
    isPurchased: true,
    purchasedBy: MEMBER_UID,
    purchasedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, ITEM_PATH), {
    isAddedToInventory: true,
    updatedAt: serverTimestamp(),
  }));
});

test("imported items are read-only for clients", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), ITEM_PATH), {
      isPurchased: true,
      purchasedBy: MEMBER_UID,
      isAddedToInventory: true,
      inventoryItemId: "inv-1",
    });
  });
  await assertFails(updateDoc(doc(dbAs(MEMBER_UID), ITEM_PATH), {
    quantity: 5,
    updatedAt: serverTimestamp(),
  }));
});

test("owner saves valid notificationSettings only", async () => {
  const db = dbAs(MEMBER_UID);
  const settings = {
    pushEnabled: true,
    expiryAlertDays: [1, 3],
    reminderHour: 8,
    shoppingReminderEnabled: true,
    shoppingReminderWeekday: 6,
    updatedAt: serverTimestamp(),
  };
  await assertSucceeds(updateDoc(doc(db, "users", MEMBER_UID), {
    notificationSettings: settings,
  }));
  await assertFails(updateDoc(doc(db, "users", MEMBER_UID), {
    notificationSettings: {...settings, reminderHour: 24},
  }));
  await assertFails(updateDoc(doc(db, "users", MEMBER_UID), {
    notificationSettings: {...settings, expiryAlertDays: [2]},
  }));
  await assertFails(updateDoc(doc(db, "users", MEMBER_UID), {
    notificationSettings: {...settings, role: "admin"},
  }));
});
