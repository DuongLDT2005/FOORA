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
  return `[out:json][timeout:25];\n(\n  nwr["shop"~"^(supermarket|convenience|greengrocer|butcher)$"](around:${radiusMeters},${lat},${lng});\n  nwr["amenity"="marketplace"](around:${radiusMeters},${lat},${lng});\n);\nout center tags 200;`;
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

  return stores.slice(0, 200);
}

function resolveKind(tags: Record<string, string | undefined>): StoreKind | null {
  if (tags.amenity === "marketplace") {
    return "marketplace";
  }
  const shop = tags.shop as StoreKind | undefined;
  return shop && STORE_KINDS.has(shop) ? shop : null;
}

function defaultName(kind: StoreKind): string {
  return kind === "marketplace" ? "Chợ" : "Siêu thị";
}

function buildAddress(tags: Record<string, string | undefined>): string | null {
  const street = [tags["addr:housenumber"], tags["addr:street"]]
    .filter((value): value is string => Boolean(value?.trim()))
    .join(" ");
  const parts = [street, tags["addr:district"]]
    .filter((value): value is string => Boolean(value?.trim()));
  return parts.length > 0 ? parts.join(", ") : null;
}
