import {defineString} from "firebase-functions/params";
import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {OverpassClient} from "../services/overpass_client";
import {
  NearbyStoreRecord,
} from "../services/overpass_query";
import {NearbyStoresResult, PlacesService} from "../services/places_service";

const overpassUrl = defineString("OVERPASS_URL", {
  default: "https://overpass-api.de/api/interpreter",
});

interface GetNearbyStoresInput {
  lat: number;
  lng: number;
  radiusMeters?: number;
}

export const getNearbyStores = onCall<Partial<GetNearbyStoresInput>>(
  {region: REGION, timeoutSeconds: 70, maxInstances: 5},
  async (request): Promise<ApiResponse<NearbyStoresResult>> => {
    try {
      // The local Emulator Suite is used for UI development without a
      // Firebase Auth session. Keep the production endpoint protected, while
      // allowing an unauthenticated Android emulator to exercise the nearby
      // places flow.
      if (process.env.FUNCTIONS_EMULATOR !== "true") {
        await getAuthenticatedUser(request);
      }
      const {lat, lng, radiusMeters} = request.data ?? {};
      if (!isLatitude(lat) || !isLongitude(lng)) {
        throwInvalidArgument("Tọa độ vị trí không hợp lệ.");
      }
      if (radiusMeters != null &&
          (typeof radiusMeters !== "number" || !Number.isFinite(radiusMeters))) {
        throwInvalidArgument("Bán kính tìm kiếm không hợp lệ.");
      }

      const radius = Math.min(5000, Math.max(500, radiusMeters ?? 3000));
      if (process.env.FUNCTIONS_EMULATOR === "true") {
        return {
          success: true,
          data: {
            stores: buildEmulatorStores(lat, lng),
            cached: false,
            source: "emulator-mock",
          },
        };
      }

      const service = new PlacesService(
        undefined,
        new OverpassClient(overpassUrl.value())
      );
      const data = await service.getNearbyStores(lat, lng, radius);
      return {success: true, data};
    } catch (error) {
      handleFunctionError(error, "getNearbyStores");
    }
  }
);

function isLatitude(value: unknown): value is number {
  return typeof value === "number" &&
    Number.isFinite(value) && value >= -90 && value <= 90;
}

function isLongitude(value: unknown): value is number {
  return typeof value === "number" &&
    Number.isFinite(value) && value >= -180 && value <= 180;
}

/** Visible development fixtures placed a few hundred metres around GPS. */
function buildEmulatorStores(lat: number, lng: number): NearbyStoreRecord[] {
  return [
    {
      id: "emulator-supermarket",
      name: "Siêu thị mẫu (Emulator)",
      kind: "supermarket",
      lat: lat + 0.0018,
      lng: lng - 0.001,
      address: "Dữ liệu phát triển cục bộ",
      openingHours: "08:00–22:00",
    },
    {
      id: "emulator-convenience",
      name: "Cửa hàng tiện lợi mẫu (Emulator)",
      kind: "convenience",
      lat: lat - 0.0008,
      lng: lng + 0.0019,
      address: "Dữ liệu phát triển cục bộ",
      openingHours: "Mở cửa 24/7",
    },
    {
      id: "emulator-market",
      name: "Chợ mẫu (Emulator)",
      kind: "marketplace",
      lat: lat + 0.0009,
      lng: lng + 0.0014,
      address: "Dữ liệu phát triển cục bộ",
      openingHours: "06:00–18:00",
    },
  ];
}
