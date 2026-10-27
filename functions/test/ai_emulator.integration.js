// Run with firebase.ai-test.json and Firestore Emulator.
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");
const {execFileSync} = require("node:child_process");
const {Timestamp} = require("firebase-admin/firestore");
const {db} = require("../lib/config/firebase.js");
const {AiActionService} = require("../lib/ai/services/ai_action_service.js");
const {AiAssistantService, assistantQuotaDay} =
  require("../lib/ai/services/ai_assistant_service.js");

async function main() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("This integration test only runs with Firestore Emulator.");
  }
  const suffix = randomUUID().slice(0, 8);
  const uid = `ai-test-${suffix}`;
  const householdId = `household-${suffix}`;
  const household = db.collection("households").doc(householdId);
  const userChats = db.collection("users").doc(uid).collection("ai_chats");
  const itemRef = household.collection("inventory_items").doc("egg-batch");
  const now = Timestamp.now();
  await Promise.all([
    db.collection("memberships").doc("free").set({isActive: true,
      foodLimit: 30, aiAssistantDailyQuota: 2}),
    db.collection("food_categories").doc("meat").set({isActive: true}),
    db.collection("food_categories").doc("seafood").set({isActive: true}),
    db.collection("food_categories").doc("vegetables").set({isActive: true}),
    db.collection("storage_locations").doc("fridge").set({isActive: true}),
    household.set({ownerId: uid, members: [uid], activeItemCount: 1}),
    itemRef.set({name: "Trứng", normalizedName: "trung", quantity: 3,
      initialQuantity: 3, remainingPercentage: 100, unit: "quả",
      status: "active", expirationDate: Timestamp.fromDate(new Date("2026-11-01")),
      createdAt: now, updatedAt: now}),
  ]);
  const user = {uid, email: "", role: "member", activeHouseholdId: householdId,
    membershipId: "free", isActive: true};
  const requestId = randomUUID();
  const question = {requestId, sessionId: randomUUID(), householdId,
    message: "Hôm nay ăn gì?",
    inputMode: "text"};
  await assert.rejects(AiAssistantService.send(user, question, ""),
    {code: "failed-precondition"});
  const usage = await db.collection("users").doc(uid)
    .collection("ai_usage_days").doc(assistantQuotaDay(new Date())).get();
  assert.equal(usage.data().used, 0);
  const request = await db.collection("users").doc(uid)
    .collection("ai_requests").doc(requestId).get();
  assert.equal(request.data().status, "failed");
  await assert.rejects(AiAssistantService.send(user,
    {...question, message: "Kho còn gì?"}, ""),
  {code: "failed-precondition"});
  assert.equal((await usage.ref.get()).data().used, 0);
  const emptyHouseholdId = `empty-${suffix}`;
  await db.collection("households").doc(emptyHouseholdId).set({ownerId: uid,
    members: [uid], activeItemCount: 0});
  const emptyInput = {requestId: randomUUID(), sessionId: randomUUID(),
    householdId: emptyHouseholdId,
    message: "Trong tủ còn thực phẩm nào sắp hết hạn?", inputMode: "text"};
  const emptyUser = {...user, activeHouseholdId: emptyHouseholdId};
  const emptyResult = await AiAssistantService.send(emptyUser, emptyInput, "");
  assert.match(emptyResult.reply, /chưa có thực phẩm nào/);
  assert.deepEqual(emptyResult.recipes, []);
  assert.deepEqual(emptyResult.actions, []);
  assert.deepEqual(await AiAssistantService.send(emptyUser, emptyInput, ""),
    emptyResult);
  assert.equal((await usage.ref.get()).data().used, 1);
  const entryInput = {requestId: randomUUID(), sessionId: emptyInput.sessionId,
    householdId: emptyHouseholdId,
    message: "hãy nạp vào tủ lạnh của tôi 10kg cá, 10kg thịt, 5kg cà rốt, " +
      "4 kg khoai tây, 10 bó rau dùng cho cả tuần", inputMode: "text"};
  const entry = await AiAssistantService.send(emptyUser, entryInput, "");
  assert.equal(entry.actions.length, 5);
  // Both questions share one session: its title is the first question.
  const session = (await db.collection("users").doc(uid)
    .collection("ai_sessions").doc(emptyInput.sessionId).get()).data();
  assert.equal(session.title, emptyInput.message);
  assert.equal(session.messageCount, 4);
  assert.equal(session.householdId, emptyHouseholdId);
  assert.equal((await userChats.doc(entry.messageId).get()).data().sessionId,
    emptyInput.sessionId);
  await db.collection("memberships").doc("free")
    .update({aiAssistantDailyQuota: 10});
  await assert.rejects(AiAssistantService.send(user, {...question,
    requestId: randomUUID(), sessionId: emptyInput.sessionId}, ""),
  {code: "permission-denied"}, "a session stays in its household");
  assert.equal((await db.collection("households").doc(emptyHouseholdId)
    .collection("inventory_items").get()).size, 0);
  const futureDate = new Date(Date.now() + 7 * 86400000)
    .toISOString().slice(0, 10);
  const entryDecisions = entry.actions.map((action) => ({
    actionId: action.actionId, accept: true, name: action.name,
    quantity: action.quantity, unit: action.unit, categoryId: action.categoryId,
    storageLocationId: action.storageLocationId, expirationDate: futureDate,
  }));
  const entryApplied = await AiActionService.apply(emptyUser,
    entry.messageId, entryDecisions);
  assert.equal(entryApplied.results.length, 5);
  assert.ok(entryApplied.results.every((result) =>
    result.resolution === "applied"));
  assert.equal((await db.collection("households").doc(emptyHouseholdId)
    .collection("inventory_items").get()).size, 5);
  assert.deepEqual(await AiActionService.apply(emptyUser,
    entry.messageId, entryDecisions), entryApplied);
  const messageId = `${randomUUID()}-assistant`;
  await userChats.doc(messageId).set({
    householdId, isUser: false, actionStatus: "proposed", createdAt: Timestamp.now(),
    actions: [
      {actionId: "consume-eggs", type: "consume", name: "Trứng", quantity: 2,
        unit: "quả", reviewState: "ready", resolution: "pending",
        candidateBatches: [{itemId: itemRef.id, name: "Trứng", quantity: 3,
          initialQuantity: 3, unit: "quả", expirationDate: "2026-11-01",
          updatedAtMillis: now.toMillis(), createdAtMillis: now.toMillis()}]},
      {actionId: "add-meat", type: "add_inventory", name: "Thịt heo", quantity: 1,
        unit: "kg", reviewState: "needsReview", resolution: "pending",
        candidateBatches: []},
    ],
  });
  const decisions = [
    {actionId: "consume-eggs", accept: true, quantity: 2, unit: "quả"},
    {actionId: "add-meat", accept: true, name: "Thịt heo", quantity: 1,
      unit: "kg", categoryId: "meat", storageLocationId: "fridge"},
  ];
  const [first, retry] = await Promise.all([
    AiActionService.apply(user, messageId, decisions),
    AiActionService.apply(user, messageId, decisions),
  ]);
  assert.deepEqual(first, retry);
  assert.equal(first.actionStatus, "applied");
  const egg = (await itemRef.get()).data();
  assert.equal(egg.quantity, 1);
  assert.equal(egg.remainingPercentage, 33);
  const meat = (await household.collection("inventory_items")
    .doc(first.results[1].itemIds[0]).get()).data();
  assert.equal(meat.quantity, 1);
  assert.equal(meat.initialQuantity, 1);
  assert.equal((await household.get()).data().activeItemCount, 2);
  await assert.rejects(
    AiActionService.apply(user, messageId, [
      {...decisions[0], quantity: 1}, decisions[1],
    ]),
    {code: "failed-precondition"}
  );
  await assert.rejects(
    AiActionService.apply({...user, activeHouseholdId: "another"},
      messageId, decisions),
    {code: "permission-denied"}
  );
  const conflictId = `${randomUUID()}-assistant`;
  await userChats.doc(conflictId).set({
    householdId, isUser: false, actionStatus: "proposed", createdAt: Timestamp.now(),
    actions: [{actionId: "stale", type: "consume", name: "Trứng", quantity: 1,
      unit: "quả", reviewState: "ready", resolution: "pending",
      candidateBatches: [{itemId: itemRef.id, name: "Trứng", quantity: 3,
        initialQuantity: 3, unit: "quả", expirationDate: "2026-11-01",
        updatedAtMillis: now.toMillis(), createdAtMillis: now.toMillis()}]}],
  });
  await assert.rejects(AiActionService.apply(user, conflictId,
    [{actionId: "stale", accept: true, quantity: 1, unit: "quả"}]),
  {code: "failed-precondition"});
  assert.equal((await itemRef.get()).data().quantity, 1);
  const secondRef = household.collection("inventory_items").doc("egg-batch-2");
  await secondRef.set({name: "Trứng", normalizedName: "trung", quantity: 2,
    initialQuantity: 2, remainingPercentage: 100, unit: "quả",
    status: "active", expirationDate: Timestamp.fromDate(new Date("2026-11-04")),
    createdAt: Timestamp.now(), updatedAt: Timestamp.now()});
  const batchSnapshots = await Promise.all([itemRef.get(), secondRef.get()]);
  const candidates = batchSnapshots.map((snapshot) => ({
    itemId: snapshot.id, name: snapshot.data().name,
    quantity: snapshot.data().quantity,
    initialQuantity: snapshot.data().initialQuantity,
    unit: snapshot.data().unit,
    expirationDate: snapshot.id === itemRef.id ? "2026-11-01" : "2026-11-04",
    updatedAtMillis: snapshot.data().updatedAt.toMillis(),
    createdAtMillis: snapshot.data().createdAt.toMillis(),
  }));
  const fefoId = `${randomUUID()}-assistant`;
  await userChats.doc(fefoId).set({householdId, isUser: false,
    actionStatus: "proposed", createdAt: Timestamp.now(),
    actions: [{actionId: "fefo", type: "consume", name: "Trứng",
      quantity: 2, unit: "quả", reviewState: "ready",
      resolution: "pending", candidateBatches: candidates}]});
  const fefoResult = await AiActionService.apply(user, fefoId,
    [{actionId: "fefo", accept: true, quantity: 2, unit: "quả"}]);
  assert.deepEqual(fefoResult.results[0].itemIds,
    [itemRef.id, secondRef.id]);
  assert.equal((await itemRef.get()).data().status, "consumed");
  assert.equal((await secondRef.get()).data().quantity, 1);

  const secondCurrent = (await secondRef.get()).data();
  const outsideId = `${randomUUID()}-assistant`;
  await userChats.doc(outsideId).set({householdId, isUser: false,
    actionStatus: "proposed", createdAt: Timestamp.now(),
    actions: [{actionId: "outside", type: "consume", name: "Trứng",
      quantity: 1, unit: "quả", reviewState: "ready",
      resolution: "pending", candidateBatches: [{...candidates[1],
        quantity: 1, updatedAtMillis: secondCurrent.updatedAt.toMillis()}]}]});
  await assert.rejects(AiActionService.apply(user, outsideId,
    [{actionId: "outside", accept: true, quantity: 1, unit: "quả",
      targetItemId: itemRef.id}]), {code: "failed-precondition"});
  assert.equal((await secondRef.get()).data().quantity, 1);

  await db.collection("memberships").doc("free").update({foodLimit: 1});
  const overLimitId = `${randomUUID()}-assistant`;
  await userChats.doc(overLimitId).set({householdId, isUser: false,
    actionStatus: "proposed", createdAt: Timestamp.now(),
    actions: [{actionId: "over-limit", type: "add_inventory", name: "Cá",
      quantity: 1, unit: "kg", reviewState: "needsReview",
      resolution: "pending", candidateBatches: []}]});
  await assert.rejects(AiActionService.apply(user, overLimitId,
    [{actionId: "over-limit", accept: true, name: "Cá", quantity: 1,
      unit: "kg", categoryId: "meat", storageLocationId: "fridge"}]),
  {code: "resource-exhausted"});
  const legacyRef = household.collection("inventory_items").doc("legacy-batch");
  await legacyRef.set({name: "Sữa", quantity: 2, remainingPercentage: 50,
    status: "active"});
  const migration = require.resolve("../lib/scripts/backfill_initial_quantity.js");
  const dryRun = execFileSync(process.execPath, [migration],
    {encoding: "utf8"});
  assert.equal(JSON.parse(dryRun).mode, "dry-run");
  assert.equal((await legacyRef.get()).data().initialQuantity, undefined);
  const applied = execFileSync(process.execPath, [migration, "--apply"],
    {encoding: "utf8"});
  assert.equal(JSON.parse(applied).mode, "apply");
  assert.equal((await legacyRef.get()).data().initialQuantity, 4);
  assert.equal((await legacyRef.get()).data().remainingPercentage, 50);
  console.info("AI emulator integration passed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
