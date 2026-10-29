export type StoreKind =
  | "supermarket"
  | "convenience"
  | "greengrocer"
  | "butcher"
  | "marketplace";

export interface NearbyStoreRecord {
  id: string;
  name: string;
  kind: StoreKind;
  lat: number;
  lng: number;
  address: string | null;
  openingHours: string | null;
}

export interface OverpassElement {
  type: "node" | "way" | "relation";
  id: number;
  lat?: number;
  lon?: number;
  center?: {lat?: number; lon?: number};
  tags?: Record<string, string | undefined>;
}

/** Overpass returns elements by id, not distance, so fetch a wide pool. */
export const OVERPASS_RESULT_LIMIT = 1000;
export const MAX_CACHED_STORES = 200;

const STORE_KINDS: ReadonlySet<StoreKind> = new Set([
  "supermarket",
  "convenience",
  "greengrocer",
  "butcher",
  "marketplace",
]);

export function buildCellId(
  lat: number,
  lng: number,
  radiusMeters: number
): string {
  return `${lat.toFixed(2)}_${lng.toFixed(2)}_${radiusMeters}`;
}

export function buildOverpassQuery(
  lat: number,
  lng: number,
  radiusMeters: number
): string {
  return `[out:json][timeout:25];\n(\n  nwr["shop"~"^(supermarket|convenience|greengrocer|butcher)$"](around:${radiusMeters},${lat},${lng});\n  nwr["amenity"="marketplace"](around:${radiusMeters},${lat},${lng});\n);\nout center tags ${OVERPASS_RESULT_LIMIT};`;
}

export function parseNearbyStores(
  elements: readonly OverpassElement[]
): NearbyStoreRecord[] {
  const seen = new Set<string>();
  const stores: NearbyStoreRecord[] = [];

  for (const element of elements) {
    const tags = element.tags ?? {};
    const kind = resolveKind(tags);
    const lat = element.lat ?? element.center?.lat;
    const lng = element.lon ?? element.center?.lon;

    if (!kind || !Number.isFinite(lat) || !Number.isFinite(lng)) {
      continue;
    }
    if (kind === "convenience" && !tags.name && !tags.brand) {
      continue;
    }

    const id = `${element.type}/${element.id}`;
    if (seen.has(id)) {
      continue;
    }
    seen.add(id);
    stores.push({
      id,
      name: tags.name?.trim() || tags.brand?.trim() || defaultName(kind),
      kind,
      lat: lat as number,
      lng: lng as number,
      address: buildAddress(tags),
      openingHours: tags.opening_hours?.trim() || null,
    });
  }

  return stores;
}

/** Keeps the stores closest to the query centre. */
export function selectNearestStores(
  stores: readonly NearbyStoreRecord[],
  lat: number,
  lng: number,
  limit = MAX_CACHED_STORES
): NearbyStoreRecord[] {
  return stores
    .map((store) => ({
      store,
      distance: distanceMeters(lat, lng, store.lat, store.lng),
    }))
    .sort((a, b) => a.distance - b.distance)
    .slice(0, limit)
    .map(({store}) => store);
}

/** Haversine distance in metres. */
export function distanceMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const toRadians = (degrees: number) => degrees * Math.PI / 180;
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLng / 2) ** 2;
  return 2 * 6_371_000 * Math.asin(Math.sqrt(a));
}

function resolveKind(tags: Record<string, string | undefined>): StoreKind | null {
  if (tags.amenity === "marketplace") {
    return "marketplace";
  }
  const shop = tags.shop as StoreKind | undefined;
  return shop && STORE_KINDS.has(shop) ? shop : null;
}

function defaultName(kind: StoreKind): string {
  switch (kind) {
  case "marketplace":
    return "Chợ";
  case "convenience":
    return "Cửa hàng tiện lợi";
  case "greengrocer":
    return "Cửa hàng rau củ";
  case "butcher":
    return "Cửa hàng thịt";
  default:
    return "Siêu thị";
  }
}

function buildAddress(tags: Record<string, string | undefined>): string | null {
  const street = [tags["addr:housenumber"], tags["addr:street"]]
    .filter((value): value is string => Boolean(value?.trim()))
    .join(" ");
  const parts = [street, tags["addr:district"]]
    .filter((value): value is string => Boolean(value?.trim()));
  return parts.length > 0 ? parts.join(", ") : null;
}
