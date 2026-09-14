import {UserRecord} from "firebase-admin/auth";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {db} from "../../config/firebase";
import {Collections} from "../../constants/collections";

export class AuthService {
  /**
   * Initializes user document, default household, and initial AI quota atomically
   * using Firestore transaction for true idempotency.
   */
  static async handleNewUser(user: UserRecord): Promise<void> {
    const uid = user.uid;
    const email = user.email || "";

    const userRef = db.collection(Collections.USERS).doc(uid);
    const householdRef = db.collection(Collections.HOUSEHOLDS).doc();
    const aiUsageRef = userRef
      .collection(Collections.AI_USAGE)
      .doc(Collections.AI_USAGE_CURRENT_DOC);

    const now = new Date();
    const period = now.toISOString().slice(0, 7); // Format: "YYYY-MM"
    const serverTimestamp = FieldValue.serverTimestamp();

    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);

      // Idempotency check: Only skip if user is ALREADY fully initialized by backend
      if (userDoc.exists && userDoc.data()?.activeHouseholdId) {
        logger.info(
          `[AuthService] User ${uid} already initialized. Skipping creation.`
        );
        return;
      }

      // 1. Create Default Household document
      const currentFullName = userDoc.exists ?
        (userDoc.data()?.fullName as string | undefined) :
        undefined;
      const displayName = currentFullName?.trim() ||
        user.displayName?.trim() ||
        email.split("@")[0] ||
        "tôi";
      transaction.set(householdRef, {
        name: `Tủ lạnh của ${displayName}`,
        ownerId: uid,
        members: [uid],
        activeItemCount: 0,
        createdAt: serverTimestamp,
        updatedAt: serverTimestamp,
      });

      // 2. Create User document (without fullName, using merge: true)
      transaction.set(
        userRef,
        {
          email: email,
          role: "member",
          membershipId: "free",
          activeHouseholdId: householdRef.id,
          isActive: true,
          createdAt: serverTimestamp,
          updatedAt: serverTimestamp,
        },
        {merge: true}
      );

      // 3. Create initial AI Usage document
      transaction.set(aiUsageRef, {
        period: period,
        receiptScanUsed: 0,
        updatedAt: serverTimestamp,
      });
    });

    logger.info(
      `[AuthService] Successfully initialized user ${uid} with household ${householdRef.id}`
    );
  }
}
