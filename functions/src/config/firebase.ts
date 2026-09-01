import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK once across the entire functions codebase
if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const auth = admin.auth();
export const storage = admin.storage();
export const messaging = admin.messaging();

export const REGION = "asia-southeast1";
export {admin};
