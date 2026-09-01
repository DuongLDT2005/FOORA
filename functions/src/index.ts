import {setGlobalOptions} from "firebase-functions/v2";
import {REGION} from "./config/firebase";

// Set global function options
setGlobalOptions({
  maxInstances: 10,
  region: REGION,
});

// Export Shared Infrastructure
export * from "./config/firebase";
export * from "./constants/collections";
export * from "./types";
export * from "./utils/auth";
export * from "./utils/errors";

// Export Feature Submodules
export * as authFunctions from "./auth";
export * as inventoryFunctions from "./inventory";
export * as receiptFunctions from "./receipt";
export * as aiFunctions from "./ai";
export * as notificationFunctions from "./notification";
export * as membershipFunctions from "./membership";
export * as paymentFunctions from "./payment";
export * as householdFunctions from "./household";
export * as adminFunctions from "./admin";
