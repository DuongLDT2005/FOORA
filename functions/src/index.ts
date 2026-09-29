// Load .env file explicitly so GEMINI_API_KEY is always available,
// even when running under firebase emulators:start locally.
import * as dotenv from "dotenv";
import * as path from "path";
dotenv.config({path: path.resolve(__dirname, "../../.env")});

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
export * from "./payment";


