import {defineString} from "firebase-functions/params";
import {onCall} from "firebase-functions/v2/https";
import {REGION} from "../../config/firebase";
import {ApiResponse} from "../../types";
import {getAuthenticatedUser} from "../../utils/auth";
import {handleFunctionError, throwInvalidArgument} from "../../utils/errors";
import {OverpassClient} from "../services/overpass_client";
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
      await getAuthenticatedUser(request);
      const {lat, lng, radiusMeters} = request.data ?? {};
      if (!isLatitude(lat) || !isLongitude(lng)) {
        throwInvalidArgument("Tọa độ vị trí không hợp lệ.");
      }
      if (radiusMeters != null &&
          (typeof radiusMeters !== "number" || !Number.isFinite(radiusMeters))) {
        throwInvalidArgument("Bán kính tìm kiếm không hợp lệ.");
      }

      const radius = Math.min(5000, Math.max(500, radiusMeters ?? 3000));
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
