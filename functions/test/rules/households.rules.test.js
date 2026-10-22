/**
 * Firestore security-rules tests for households and invitation collections.
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
const {doc, getDoc, setDoc, updateDoc} = require("firebase/firestore");

const HOUSEHOLD_ID = "home-1";
const OWNER_UID = "owner-1";
const MEMBER_UID = "member-1";
const OUTSIDER_UID = "outsider-1";

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
      ownerId: OWNER_UID,
      members: [OWNER_UID, MEMBER_UID],
      activeItemCount: 0,
    });
    await setDoc(doc(db, "household_invitations", "ABCD23"), {
      code: "ABCD23",
      householdId: HOUSEHOLD_ID,
      status: "active",
    });
  });
});

function dbAs(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

test("members can read their household, outsiders cannot", async () => {
  await assertSucceeds(getDoc(doc(dbAs(MEMBER_UID), "households", HOUSEHOLD_ID)));
  await assertFails(getDoc(doc(dbAs(OUTSIDER_UID), "households", HOUSEHOLD_ID)));
});

test("only the owner can rename the household", async () => {
  await assertSucceeds(
    updateDoc(doc(dbAs(OWNER_UID), "households", HOUSEHOLD_ID), {name: "Nhà mới"}),
  );
  await assertFails(
    updateDoc(doc(dbAs(MEMBER_UID), "households", HOUSEHOLD_ID), {name: "Nhà B"}),
  );
});

test("clients cannot change the member list", async () => {
  await assertFails(
    updateDoc(doc(dbAs(OUTSIDER_UID), "households", HOUSEHOLD_ID), {
      members: [OWNER_UID, MEMBER_UID, OUTSIDER_UID],
    }),
  );
  await assertFails(
    updateDoc(doc(dbAs(OWNER_UID), "households", HOUSEHOLD_ID), {
      members: [OWNER_UID],
    }),
  );
});

test("invitations and attempt counters are server-only", async () => {
  await assertFails(getDoc(doc(dbAs(OWNER_UID), "household_invitations", "ABCD23")));
  await assertFails(
    setDoc(doc(dbAs(OUTSIDER_UID), "household_invitations", "ZZZZ99"), {
      householdId: HOUSEHOLD_ID,
      status: "active",
    }),
  );
  await assertFails(getDoc(doc(dbAs(OUTSIDER_UID), "invite_attempts", OUTSIDER_UID)));
  await assertFails(
    setDoc(doc(dbAs(OUTSIDER_UID), "invite_attempts", OUTSIDER_UID), {failedCount: 0}),
  );
});
