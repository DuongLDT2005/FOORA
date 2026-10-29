# Nearby Stores Map

The mobile route `/nearby-stores` uses the device's foreground location to
show nearby supermarkets, convenience stores, greengrocers, butchers and
markets on OpenStreetMap.

- Flutter requests location only while this screen is open. Android declares
  coarse and fine foreground permission; iOS declares the when-in-use message.
- The client calls authenticated Firebase callable `getNearbyStores`; it never
  requests Overpass directly.
- The callable rounds the query centre to two decimal places, reads/writes the
  server-only `place_cache` collection, and caches results for 24 hours.
- Store distances shown in the app are straight-line distances. The directions
  action opens Google Maps with the selected destination coordinates.
- OSM tiles use `com.foora.foora` as the package identifier and retain visible
  OpenStreetMap attribution. The app does not prefetch or download tiles.

## Firebase Functions

`getNearbyStores({ lat, lng, radiusMeters? })` requires an authenticated user.
Coordinates are validated and radius is clamped to 500–5000 m (default 3000).
Its response is `ApiResponse<{ stores, cached, source: 'openstreetmap' }>`,
where `cached` tells the client that the 24-hour cache was used.

`OVERPASS_URL` is a non-secret Firebase parameter. Its production default is
`https://overpass-api.de/api/interpreter`.

Overpass returns elements by ID, not by distance, so the callable asks for up
to 1000 elements and caches the 200 nearest to the cell centre. A 429/504 is
retried once after 30 s only when the 62 s query budget still allows it;
otherwise the stale cache is returned, or `unavailable` when there is none.

## Local development

- The Functions Emulator skips the auth check and returns three sample stores
  around the requested point (`source: 'emulator-mock'`), because many dev
  networks cannot reach Overpass. Set `PLACES_LIVE_OVERPASS=true` in
  `functions/.env.local` to query the real service from the emulator.
- Android emulators often have no GPS fix. Add `"DEV_LOCATION": "lat,lng"`
  to `.env.json` to use a fixed position instead; release builds ignore it.
  Alternatively set a point in the emulator's Extended controls → Location.
- Emulator runs load tiles from `a.tile.openstreetmap.org` because some
  emulator DNS setups resolve `tile.openstreetmap.org` to localhost; other
  builds use `tile.openstreetmap.org` as the tile policy asks.
