import {Firestore} from "firebase-admin/firestore";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";
import {
  buildCellId,
  buildOverpassQuery,
  NearbyStoreRecord,
  parseNearbyStores,
} from "./overpass_query";
import {OverpassClient} from "./overpass_client";

const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

export interface NearbyStoresResult {
  stores: NearbyStoreRecord[];
  cached: boolean;
  source: "openstreetmap";
}

interface PlaceCacheDocument {
  stores: NearbyStoreRecord[];
  fetchedAt: {toDate?: () => Date} | Date;
}

export class PlacesService {
  constructor(
    private readonly firestore: Firestore = db,
    private readonly overpassClient: OverpassClient,
    private readonly now: () => Date = () => new Date()
  ) {}

  async getNearbyStores(
    lat: number,
    lng: number,
    radiusMeters: number
  ): Promise<NearbyStoresResult> {
    const center = {lat: roundCellCenter(lat), lng: roundCellCenter(lng)};
    const cellId = buildCellId(center.lat, center.lng, radiusMeters);
    const cacheRef = this.firestore.collection(Collections.PLACE_CACHE).doc(cellId);
    const snapshot = await cacheRef.get();
    const cached = snapshot.exists ? snapshot.data() as PlaceCacheDocument : null;

    if (cached && isFresh(cached.fetchedAt, this.now())) {
      return {stores: cached.stores, cached: true, source: "openstreetmap"};
    }

    try {
      const query = buildOverpassQuery(
        center.lat,
        center.lng,
        radiusMeters + 800
      );
      const elements = await this.overpassClient.query(query);
      const stores = parseNearbyStores(elements);
      await cacheRef.set({
        stores,
        fetchedAt: this.now(),
        radius: radiusMeters,
        center,
      });
      return {stores, cached: false, source: "openstreetmap"};
    } catch (error) {
      if (cached) {
        return {stores: cached.stores, cached: true, source: "openstreetmap"};
      }
      throw error;
    }
  }
}

function roundCellCenter(value: number): number {
  return Number(value.toFixed(2));
}

function isFresh(value: PlaceCacheDocument["fetchedAt"], now: Date): boolean {
  const date = value instanceof Date ? value : value.toDate?.();
  return date != null && now.getTime() - date.getTime() < CACHE_TTL_MS;
}
