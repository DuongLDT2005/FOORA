/**
 * Firestore security-rules tests for households/{id}/inventory_items.
 * Run with `npm run test:rules` (starts the Firestore emulator).
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
  doc,
  setDoc,
  updateDoc,
  getDoc,
  serverTimestamp,
  Timestamp,
} = require("firebase/firestore");

const HOUSEHOLD_ID = "home-1";
const ITEM_ID = "item-1";
const MEMBER_UID = "member-1";

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-foora-rules",
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, "../../../firestore.rules"),
        "utf8",
      ),
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
      members: [MEMBER_UID],
    });
    await setDoc(
      doc(db, "households", HOUSEHOLD_ID, "inventory_items", ITEM_ID),
      {
        name: "Sữa tươi",
        quantity: 1,
        remainingPercentage: 100,
        status: "active",
        statusChangedAt: Timestamp.fromDate(new Date("2026-10-01")),
      },
    );
  });
});

function itemRef() {
  const db = testEnv.authenticatedContext(MEMBER_UID).firestore();
  return doc(db, "households", HOUSEHOLD_ID, "inventory_items", ITEM_ID);
}

test("rejects a status change without statusChangedAt", async () => {
  await assertFails(
    updateDoc(itemRef(), {status: "discarded", updatedAt: serverTimestamp()}),
  );
});

test("rejects a client-chosen statusChangedAt", async () => {
  await assertFails(
    updateDoc(itemRef(), {
      status: "discarded",
      statusChangedAt: Timestamp.fromDate(new Date("2020-01-01")),
    }),
  );
});

test("accepts a status change stamped with server time", async () => {
  await assertSucceeds(
    updateDoc(itemRef(), {
      status: "discarded",
      statusChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test("accepts an edit that keeps the status unchanged", async () => {
  await assertSucceeds(
    updateDoc(itemRef(), {quantity: 2, updatedAt: serverTimestamp()}),
  );
});

const LOCKED_ITEM_ID = "item-locked";
const LOCKED_MEMBER_UID = "member-locked";

async function seedLockedHousehold() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "households", HOUSEHOLD_ID), {
      name: "Nhà",
      members: [MEMBER_UID, LOCKED_MEMBER_UID],
      lockedMembers: [LOCKED_MEMBER_UID],
    });
    await setDoc(
      doc(db, "households", HOUSEHOLD_ID, "inventory_items", LOCKED_ITEM_ID),
      {
        name: "Trứng",
        quantity: 2,
        initialQuantity: 2,
        remainingPercentage: 100,
        status: "active",
        isLocked: true,
        statusChangedAt: Timestamp.fromDate(new Date("2026-10-01")),
      },
    );
  });
}

function lockedItemRef(uid) {
  const db = testEnv.authenticatedContext(uid).firestore();
  return doc(db, "households", HOUSEHOLD_ID, "inventory_items", LOCKED_ITEM_ID);
}

test("rejects editing a locked item", async () => {
  await seedLockedHousehold();
  await assertFails(
    updateDoc(lockedItemRef(MEMBER_UID), {
      quantity: 1,
      remainingPercentage: 50,
      updatedAt: serverTimestamp(),
    }),
  );
});

test("rejects unlocking an item from the client", async () => {
  await seedLockedHousehold();
  await assertFails(
    updateDoc(lockedItemRef(MEMBER_UID), {
      isLocked: false,
      updatedAt: serverTimestamp(),
    }),
  );
});

test("accepts discarding a locked item", async () => {
  await seedLockedHousehold();
  await assertSucceeds(
    updateDoc(lockedItemRef(MEMBER_UID), {
      quantity: 0,
      remainingPercentage: 0,
      status: "discarded",
      statusChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test("locked members cannot read the inventory", async () => {
  await seedLockedHousehold();
  await assertFails(getDoc(lockedItemRef(LOCKED_MEMBER_UID)));
  await assertSucceeds(getDoc(lockedItemRef(MEMBER_UID)));
});
