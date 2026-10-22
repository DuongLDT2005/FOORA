import {defineSecret, defineString} from "firebase-functions/params";

/** Measurement Protocol API secret of the *demo* GA4 web stream. */
export const ga4DemoApiSecret = defineSecret("GA4_DEMO_API_SECRET");

/** Measurement ID (G-XXXX) of the *demo* GA4 property. Empty = disabled. */
export const ga4DemoMeasurementId = defineString("GA4_DEMO_MEASUREMENT_ID", {
  default: "",
});

/** First day of the simulated timeline (Vietnam time). */
export const ga4DemoStartDate = defineString("GA4_DEMO_START_DATE", {
  default: "2026-09-28",
});
