import {FieldValue, Firestore, Timestamp} from "firebase-admin/firestore";
import {Collections} from "../../constants/collections";
import {
  ExpiryHousehold,
  ExpiryInventoryItem,
  planExpiryNotifications,
  PlannedExpiryNotification,
  selectNotificationsToCreate,
} from "./expiry_planner";

const WRITE_CHUNK_SIZE = 400;

export interface ExpiryRunResult {
  created: number;
  skipped: number;
}

export class ExpiryService {
  constructor(private readonly firestore: Firestore) {}

  async run(now: Date = new Date()): Promise<ExpiryRunResult> {
    const households = await this.loadHouseholds();
    const items = await this.loadActiveItems(households);
    const planned = planExpiryNotifications({now, households, items});
    return this.persist(planned);
  }

  private async loadHouseholds(): Promise<ExpiryHousehold[]> {
    const snapshot = await this.firestore.collection(Collections.HOUSEHOLDS).get();
    return snapshot.docs.map((doc) => {
      const members = doc.get("members");
      const memberIds = Array.isArray(members) ?
        members.filter((member): member is string => typeof member === "string") :
        [];
      return {id: doc.id, memberIds};
    });
  }

  private async loadActiveItems(
    households: ExpiryHousehold[]
  ): Promise<ExpiryInventoryItem[]> {
    const items: ExpiryInventoryItem[] = [];
    for (const household of households) {
      const snapshot = await this.firestore
        .collection(Collections.HOUSEHOLDS)
        .doc(household.id)
        .collection(Collections.INVENTORY_ITEMS)
        .where("status", "==", "active")
        .get();

      for (const doc of snapshot.docs) {
        const expirationDate = toDate(doc.get("expirationDate"));
        if (!expirationDate) {
          continue;
        }
        const rawName = doc.get("name");
        items.push({
          householdId: household.id,
          inventoryItemId: doc.id,
          name: typeof rawName === "string" ? rawName : "",
          status: "active",
          expirationDate,
        });
      }
    }
    return items;
  }

  private async persist(
    planned: PlannedExpiryNotification[]
  ): Promise<ExpiryRunResult> {
    if (planned.length === 0) {
      return {created: 0, skipped: 0};
    }

    let created = 0;
    let skipped = 0;
    for (let offset = 0; offset < planned.length; offset += WRITE_CHUNK_SIZE) {
      const chunk = planned.slice(offset, offset + WRITE_CHUNK_SIZE);
      const refs = chunk.map((item) => {
        return this.firestore
          .collection(Collections.USERS)
          .doc(item.userId)
          .collection(Collections.NOTIFICATIONS)
          .doc(item.notificationId);
      });
      const snapshots = await this.firestore.getAll(...refs);
      const existingKeys = new Set<string>();
      snapshots.forEach((snapshot, index) => {
        if (snapshot.exists) {
          existingKeys.add(
            `${chunk[index].userId}/${chunk[index].notificationId}`
          );
        }
      });
      const toCreate = selectNotificationsToCreate(chunk, existingKeys);
      skipped += chunk.length - toCreate.length;
      if (toCreate.length === 0) {
        continue;
      }

      const batch = this.firestore.batch();
      for (const item of toCreate) {
        const ref = this.firestore
          .collection(Collections.USERS)
          .doc(item.userId)
          .collection(Collections.NOTIFICATIONS)
          .doc(item.notificationId);
        batch.set(ref, {
          householdId: item.householdId,
          type: item.type,
          title: item.title,
          message: item.message,
          inventoryItemId: item.inventoryItemId,
          isRead: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      created += toCreate.length;
    }

    return {created, skipped};
  }
}

function toDate(value: unknown): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }
  if (typeof value === "string" || typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}
