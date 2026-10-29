const assert = require("node:assert/strict");
const test = require("node:test");

const {
  buildCellId,
  buildOverpassQuery,
  parseNearbyStores,
  selectNearestStores,
} = require("../lib/places/services/overpass_query.js");

test("builds an Overpass query with centre and radius", () => {
  const query = buildOverpassQuery(10.77, 106.69, 3800);
  assert.match(query, /around:3800,10\.77,106\.69/);
  assert.match(query, /amenity/);
  assert.match(query, /out center tags 1000/);
  assert.equal(buildCellId(10.771, 106.691, 3000), "10.77_106.69_3000");
});

test("parses nodes and ways, and excludes unusable entries", () => {
  const stores = parseNearbyStores([
    {
      type: "node",
      id: 1,
      lat: 10.7,
      lon: 106.6,
      tags: {shop: "supermarket", name: "Co.opmart", "addr:street": "Đường A"},
    },
    {
      type: "way",
      id: 2,
      center: {lat: 10.71, lon: 106.61},
      tags: {amenity: "marketplace", "addr:district": "Quận 1"},
    },
    {type: "node", id: 3, lat: 10.7, lon: 106.6, tags: {shop: "convenience"}},
    {type: "node", id: 4, tags: {shop: "butcher", name: "Missing point"}},
  ]);

  assert.equal(stores.length, 2);
  assert.deepEqual(stores[0], {
    id: "node/1",
    name: "Co.opmart",
    kind: "supermarket",
    lat: 10.7,
    lng: 106.6,
    address: "Đường A",
    openingHours: null,
  });
  assert.equal(stores[1].name, "Chợ");
  assert.equal(stores[1].address, "Quận 1");
});

test("names unnamed stores by their kind", () => {
  const stores = parseNearbyStores([
    {type: "node", id: 5, lat: 1, lon: 1, tags: {shop: "butcher"}},
    {type: "node", id: 6, lat: 1, lon: 1, tags: {shop: "greengrocer"}},
  ]);
  assert.deepEqual(stores.map((store) => store.name), [
    "Cửa hàng thịt",
    "Cửa hàng rau củ",
  ]);
});

test("keeps the stores nearest to the query centre", () => {
  const store = (id, lat) => ({
    id, name: id, kind: "supermarket", lat, lng: 106.7,
    address: null, openingHours: null,
  });
  const nearest = selectNearestStores(
    [store("far", 10.9), store("near", 10.771), store("mid", 10.8)],
    10.77,
    106.7,
    2
  );
  assert.deepEqual(nearest.map((item) => item.id), ["near", "mid"]);
});
