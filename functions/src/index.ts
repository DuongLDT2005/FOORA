import {setGlobalOptions} from "firebase-functions/v2";
import {REGION} from "./config/firebase";

// Set global function options
setGlobalOptions({
  maxInstances: 10,
  region: REGION,
});

// Export Feature Submodules (Cloud Functions Triggers & Callables)
export * from "./auth";
export * from "./notification";
export * from "./inventory";
export * from "./receipt";


