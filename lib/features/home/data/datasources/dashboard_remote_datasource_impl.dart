import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../inventory/data/models/inventory_item_model.dart';
import 'dashboard_remote_datasource.dart';

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final FirebaseFirestore firestore;

  const DashboardRemoteDataSourceImpl({required this.firestore});

  @override
  Stream<List<InventoryItemModel>> watchActiveInventoryItems(
    String householdId,
  ) {
    return firestore
        .collection(FirestoreConstants.households)
        .doc(householdId)
        .collection(FirestoreConstants.inventoryItems)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => InventoryItemModel.fromFirestore(doc))
              .toList();
        });
  }
}
