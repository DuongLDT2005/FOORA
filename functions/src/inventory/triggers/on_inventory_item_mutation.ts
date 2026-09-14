import * as functions from "firebase-functions/v1";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {REGION, db} from "../../config/firebase";
import {Collections} from "../../constants/collections";

/**
 * Firestore Trigger: onInventoryItemMutation
 * Single Source of Truth for Status Changes and Physical Deletes.
 *
 * Rules:
 * - NO onCreate handler (addInventoryItem transaction increments counter
 *   directly to prevent double counts).
 * - onUpdate: Handles status transitions ('active' <-> 'consumed' / 'discarded').
 * - onDelete: Handles hard deletes while item was still 'active'.
 */
export const onInventoryItemMutation = functions
  .region(REGION)
  .firestore
  .document(
    `${Collections.HOUSEHOLDS}/{householdId}/${Collections.INVENTORY_ITEMS}/{itemId}`
  )
  .onWrite(async (change, context) => {
    const {householdId, itemId} = context.params;

    // 1. Case: Creation -> Handled exclusively by Callable Transaction!
    if (!change.before.exists) {
      return;
    }

    const householdRef = db.collection(Collections.HOUSEHOLDS).doc(householdId);

    // 2. Case: Deletion
    if (!change.after.exists) {
      const beforeData = change.before.data();
      if (beforeData?.status === "active") {
        logger.info(
          `[onInventoryItemMutation] Active item ${itemId} deleted. ` +
          `Decrementing activeItemCount for household ${householdId}`
        );
        await householdRef.update({
          activeItemCount: FieldValue.increment(-1),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    // 3. Case: Update (Status Transition)
    const beforeStatus = change.before.data()?.status;
    const afterStatus = change.after.data()?.status;

    if (beforeStatus === afterStatus) {
      return; // No status change, nothing to adjust for counter
    }

    let delta = 0;
    if (beforeStatus === "active" && afterStatus !== "active") {
      // Transition from active -> consumed/discarded
      delta = -1;
    } else if (beforeStatus !== "active" && afterStatus === "active") {
      // Undo back to active
      delta = 1;
    }

    if (delta !== 0) {
      logger.info(
        `[onInventoryItemMutation] Item ${itemId} status changed ` +
        `(${beforeStatus} -> ${afterStatus}). Adjusting activeItemCount ` +
        `by ${delta} for household ${householdId}`
      );
      await householdRef.update({
        activeItemCount: FieldValue.increment(delta),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });
