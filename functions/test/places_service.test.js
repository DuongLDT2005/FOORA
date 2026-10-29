const assert = require("node:assert/strict");
const test = require("node:test");

const {HttpsError} = require("firebase-functions/v2/https");
const {PlacesService} = require("../lib/places/services/places_service.js");
const {
  OverpassClient,
  OverpassError,
} = require("../lib/places/services/overpass_client.js");

const NOW = new Date("2026-10-29T08:00:00.000Z");
const CACHED_STORE = {
  id: "node/1", name: "Co.opmart", kind: "supermarket",
  lat: 10.77, lng: 106.69, address: null, openingHours: null,
};

function fakeFirestore(initial) {
  const docs = new Map(initial ? [[initial.id, initial.data]] : []);
  const writes = [];
  return {
    writes,
    collection: () => ({
      doc: (id) => ({
        get: async () => ({exists: docs.has(id), data: () => docs.get(id)}),
        set: async (data) => {
          writes.push({id, data});
          docs.set(id, data);
        },
      }),
    }),
  };
}

function fakeClient(result) {
  let calls = 0;
  return {
    get calls() {
      return calls;
    },
    query: async () => {
      calls++;
      if (result instanceof Error) throw result;
      return result;
    },
  };
}

const CELL = "10.77_106.69_3000";

test("returns a fresh cache without calling Overpass", async () => {
  const firestore = fakeFirestore({
    id: CELL,
    data: {stores: [CACHED_STORE], fetchedAt: new Date(NOW - 60_000)},
  });
  const client = fakeClient([]);
  const service = new PlacesService(firestore, client, () => NOW);

  const result = await service.getNearbyStores(10.771, 106.691, 3000);

  assert.equal(result.cached, true);
  assert.deepEqual(result.stores, [CACHED_STORE]);
  assert.equal(client.calls, 0);
});

test("refreshes a stale cache and stores the nearest results", async () => {
  const firestore = fakeFirestore({
    id: CELL,
    data: {stores: [], fetchedAt: new Date(NOW - 25 * 3600_000)},
  });
  const client = fakeClient([
    {type: "node", id: 9, lat: 10.771, lon: 106.691,
      tags: {shop: "supermarket", name: "WinMart"}},
  ]);
  const service = new PlacesService(firestore, client, () => NOW);

  const result = await service.getNearbyStores(10.771, 106.691, 3000);

  assert.equal(result.cached, false);
  assert.equal(result.stores[0].name, "WinMart");
  assert.equal(firestore.writes[0].id, CELL);
  assert.deepEqual(firestore.writes[0].data.center, {lat: 10.77, lng: 106.69});
});

test("falls back to a stale cache when Overpass fails", async () => {
  const firestore = fakeFirestore({
    id: CELL,
    data: {stores: [CACHED_STORE], fetchedAt: new Date(NOW - 25 * 3600_000)},
  });
  const client = fakeClient(new OverpassError("busy", true));
  const service = new PlacesService(firestore, client, () => NOW);

  const result = await service.getNearbyStores(10.771, 106.691, 3000);

  assert.equal(result.cached, true);
  assert.deepEqual(result.stores, [CACHED_STORE]);
});

test("reports unavailable when Overpass fails without a cache", async () => {
  const service = new PlacesService(
    fakeFirestore(),
    fakeClient(new OverpassError("busy", true)),
    () => NOW
  );

  await assert.rejects(
    service.getNearbyStores(10.771, 106.691, 3000),
    (error) => error instanceof HttpsError && error.code === "unavailable"
  );
});

function response(status, body = {elements: []}) {
  return {status, ok: status >= 200 && status < 300, json: async () => body};
}

test("retries a 429 once after waiting 30 seconds", async () => {
  const statuses = [429, 200];
  const waits = [];
  const client = new OverpassClient(
    "https://overpass.test",
    async () => response(statuses.shift()),
    async (ms) => {
      waits.push(ms);
    },
    () => 0
  );

  assert.deepEqual(await client.query("q"), []);
  assert.deepEqual(waits, [30_000]);
});

test("skips the retry when the time budget is spent", async () => {
  let clock = 0;
  const client = new OverpassClient(
    "https://overpass.test",
    async () => {
      clock = 28_000;
      return response(504);
    },
    async () => assert.fail("should not wait"),
    () => clock
  );

  await assert.rejects(client.query("q"), OverpassError);
});
