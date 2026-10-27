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
