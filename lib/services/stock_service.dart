import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../stock_management/models/stock_models.dart';
import '../repositories/stock_repository.dart';

class FirebaseStockRepository implements StockRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── Shorthand path builders ───────────────────────────────────────────────

  CollectionReference get _buildings => _db.collection('buildings');

  CollectionReference _floors(String buildingId) =>
      _buildings.doc(buildingId).collection('floors');

  CollectionReference _rooms(String buildingId, String floorId) =>
      _floors(buildingId).doc(floorId).collection('rooms');

  CollectionReference _items(
      String buildingId, String floorId, String roomId) =>
      _rooms(buildingId, floorId).doc(roomId).collection('items');

  CollectionReference get _itemsCatalog => _db.collection('itemsCatalog');

  CollectionReference _logs(
      String buildingId, String floorId, String roomId) =>
      _rooms(buildingId, floorId).doc(roomId).collection('stockLogs');

  CollectionReference _inspections(
      String buildingId, String floorId, String roomId) =>
      _rooms(buildingId, floorId).doc(roomId).collection('inspections');

  CollectionReference get _transfers => _db.collection('stockTransfers');

  CollectionReference get _assignments =>
      _db.collection('consumableAssignments');

  // ── BUILDINGS ─────────────────────────────────────────────────────────────

  @override
  Stream<List<BuildingModel>> watchBuildings() => _buildings
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs
      .map((d) =>
      BuildingModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
      .toList());

  @override
  Future<String> addBuilding(String name) async {
    final doc = await _buildings.add(BuildingModel(
      name: name,
      createdAt: DateTime.now(),
    ).toFirestore());
    return doc.id;
  }

  @override
  Future<void> updateBuilding(String id, String name) =>
      _buildings.doc(id).update({'name': name});

  @override
  Future<void> deleteBuilding(String id) =>
      _buildings.doc(id).delete();

  // ── FLOORS ────────────────────────────────────────────────────────────────

  @override
  Stream<List<FloorModel>> watchFloors(String buildingId) =>
      _floors(buildingId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((s) => s.docs
          .map((d) => FloorModel.fromFirestore(
          d.id, d.data() as Map<String, dynamic>))
          .toList());

  @override
  Future<String> addFloor(String buildingId, String name) async {
    final doc = await _floors(buildingId).add(FloorModel(
      name: name,
      buildingId: buildingId,
      createdAt: DateTime.now(),
    ).toFirestore());
    return doc.id;
  }

  @override
  Future<void> updateFloor(String buildingId, String floorId, String name) =>
      _floors(buildingId).doc(floorId).update({'name': name});

  @override
  Future<void> deleteFloor(String buildingId, String floorId) =>
      _floors(buildingId).doc(floorId).delete();

  // ── ROOMS ─────────────────────────────────────────────────────────────────

  @override
  Stream<List<RoomModel>> watchRooms(String buildingId, String floorId) =>
      _rooms(buildingId, floorId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((s) => s.docs
          .map((d) => RoomModel.fromFirestore(
          d.id, d.data() as Map<String, dynamic>))
          .toList());

  @override
  Future<String> addRoom(
      String buildingId, String floorId, String name) async {
    final doc = await _rooms(buildingId, floorId).add(RoomModel(
      name: name,
      floorId: floorId,
      buildingId: buildingId,
      createdAt: DateTime.now(),
    ).toFirestore());
    return doc.id;
  }

  @override
  Future<void> updateRoom(
      String buildingId, String floorId, String roomId, String name) =>
      _rooms(buildingId, floorId).doc(roomId).update({'name': name});

  @override
  Future<void> deleteRoom(
      String buildingId, String floorId, String roomId) =>
      _rooms(buildingId, floorId).doc(roomId).delete();

  // ── ROOM MEDIA ────────────────────────────────────────────────────────────

  /// On web, dart:io File does not exist, so we read bytes via putData().
  /// On mobile we use putFile() for streaming efficiency.
  @override
  Future<String?> uploadRoomMedia({
    required XFile xfile,
    required String buildingId,
    required String floorId,
    required String roomId,
    required bool isVideo,
    void Function(double)? onProgress,
  }) async {
    // Prefer xfile.name for extension — on web xfile.path is a blob URL.
    final src = xfile.name.isNotEmpty ? xfile.name : xfile.path;
    String ext = isVideo ? '.mp4' : '.jpg';
    if (src.contains('.')) {
      final candidate = src.substring(src.lastIndexOf('.'));
      if (candidate.length <= 5) ext = candidate;
    }

    final type = isVideo ? 'videos' : 'photos';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final storagePath =
        'stock/$buildingId/$floorId/$roomId/$type/$fileName';
    final ref = _storage.ref().child(storagePath);

    UploadTask task;
    if (kIsWeb) {
      final bytes = await xfile.readAsBytes();
      final metadata = SettableMetadata(
        contentType: isVideo ? 'video/mp4' : 'image/jpeg',
      );
      task = ref.putData(bytes, metadata);
    } else {
      task = ref.putFile(io.File(xfile.path));
    }

    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) {
        onProgress?.call(s.bytesTransferred / s.totalBytes);
      }
    });

    final snap = await task;
    return snap.ref.getDownloadURL();
  }

  @override
  Future<void> addRoomPhoto(String buildingId, String floorId,
      String roomId, String url) async {
    await _rooms(buildingId, floorId).doc(roomId).update({
      'photoUrls': FieldValue.arrayUnion([url]),
      // Feature: Media Freshness — stamp the upload time
      'lastMediaUploadedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> addRoomVideo(String buildingId, String floorId,
      String roomId, String url) async {
    await _rooms(buildingId, floorId).doc(roomId).update({
      'videoUrls': FieldValue.arrayUnion([url]),
      // Feature: Media Freshness — stamp the upload time
      'lastMediaUploadedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> removeRoomPhoto(String buildingId, String floorId,
      String roomId, String url) async {
    await _rooms(buildingId, floorId).doc(roomId).update({
      'photoUrls': FieldValue.arrayRemove([url]),
    });
  }

  @override
  Future<void> removeRoomVideo(String buildingId, String floorId,
      String roomId, String url) async {
    await _rooms(buildingId, floorId).doc(roomId).update({
      'videoUrls': FieldValue.arrayRemove([url]),
    });
  }

  // ── ITEMS ─────────────────────────────────────────────────────────────────

  @override
  Stream<List<StockItem>> watchItems(
      String buildingId, String floorId, String roomId) =>
      _items(buildingId, floorId, roomId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((s) => s.docs
          .map((d) => StockItem.fromFirestore(
          d.id, d.data() as Map<String, dynamic>))
          .toList());

  @override
  Future<String> addItem(String buildingId, String floorId, String roomId, StockItem item,
      {String buildingName = '', String floorName = '', String roomName = ''}) async {
    item.createdAt = DateTime.now();
    item.updatedAt = DateTime.now();

    final batch = _db.batch();

    if(item.id != null) {
      final _itemCatalog = _itemsCatalog.doc(item.id);
      batch.update(_itemCatalog, {'lastPrice': item.unitPrice, 'totalQuantity': FieldValue.increment(item.currentQuantity), 'updatedAt': item.updatedAt!.toIso8601String()});

      final _priceHistory = _itemCatalog.collection("priceHistory");
      batch.set(_priceHistory.doc(), {'price': item.unitPrice, 'quantity':item.currentQuantity,'timestamp': item.updatedAt!.toIso8601String(), 'store':item.store, 'bill':item.bill});
      final logRef = _logs(buildingId, floorId, roomId).doc();
      batch.set(
          logRef,
          StockLog(
            itemId: item.id!,
            itemName: item.name,
            type: 'increase',
            quantity: item.currentQuantity,
            previousQty: 0,
            newQty: item.currentQuantity,
            note: "",
            buildingName: buildingName,
            floorName: floorName,
            roomName: roomName,
          ).toFirestore());
      batch.set(_items(buildingId, floorId, roomId).doc(item.id), item.toFirestore());
      await batch.commit();
      return item.id!;
    }
    else
      {
        final _itemCatalog = _itemsCatalog.doc();
        final id = _itemCatalog.id;
        batch.set(_itemCatalog, CatalogItem(id: id, name:  item.name, lastPrice:  item.unitPrice, totalQuantity:  item.currentQuantity, createdAt:  item.createdAt, updatedAt:  item.updatedAt).toFirestore());
        final _priceHistory = _itemCatalog.collection("priceHistory");
        batch.set(_priceHistory.doc(), {'price': item.unitPrice, 'quantity': item.currentQuantity,'timestamp': item.updatedAt!.toIso8601String(), 'store':item.store, 'bill':item.bill});
        final logRef = _logs(buildingId, floorId, roomId).doc();
        batch.set(
            logRef,
            StockLog(
              itemId: id,
              itemName: item.name,
              type: 'increase',
              quantity: item.currentQuantity,
              previousQty: 0,
              newQty: item.currentQuantity,
              note: "",
              buildingName: buildingName,
              floorName: floorName,
              roomName: roomName,
            ).toFirestore());
        batch.set(_items(buildingId, floorId, roomId).doc(id), item.toFirestore());
        // final doc = await _items(buildingId, floorId, roomId)
        //     .add(item.toFirestore());
        await batch.commit();
        return id;
      }
    // final doc = await _items(buildingId, floorId, roomId)
    //     .add(item.toFirestore());
    //     return doc.id;
    //   }
  }
  // Adjust path as needed

  @override
  Future<void> updateItem(String buildingId, String floorId,
      String roomId, StockItem item) async {
    item.updatedAt = DateTime.now();
    await _items(buildingId, floorId, roomId)
        .doc(item.id)
        .update(item.toFirestore());
  }

  /// Retrieves a single catalog item summary by its ID to prefill edit screens.
  @override
  Future<CatalogItem?> getCatalogItemById(String catalogItemId) async {
    try {
      final docSnapshot = await _db.collection('itemsCatalog').doc(catalogItemId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        return CatalogItem.fromFirestore(docSnapshot.id, docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      print('Error fetching catalog item details: $e');
      return null;
    }
  }

  /// Retrieves a one-time snapshot of item summaries (id, name, unitPrice)
  /// from the global items catalog for advanced auto-completes.
  @override
  Future<List<CatalogItem>> getCatalogItemSummaries() async {
    try {
      final snapshot = await _db.collection('itemsCatalog').get();

      return snapshot.docs.map((doc) {
        return CatalogItem.fromFirestore(doc.id, doc.data());
      }).where((item) => item.name.isNotEmpty).toList();
    } catch (e) {
      print('Error fetching catalog item summaries: $e');
      return [];
    }
  }

  @override
  Future<void> deleteItem(String buildingId, String floorId,
      String roomId, String itemId) =>
      _items(buildingId, floorId, roomId).doc(itemId).delete();

  // ── QUANTITY ADJUSTMENT (writes item + log atomically) ────────────────────

  @override
  Future<void> adjustQuantity({
    required String buildingId,
    required String floorId,
    required String roomId,
    required StockItem item,
    required int delta,
    required String note,
    String buildingName = '',
    String floorName = '',
    String roomName = '',
  }) async {
    final previousQty = item.currentQuantity;
    final newQty = (previousQty + delta).clamp(0, 999999);
    final actualDelta = newQty - previousQty;
    if (actualDelta == 0) return;

    final batch = _db.batch();

    final itemRef = _items(buildingId, floorId, roomId).doc(item.id);
    batch.update(itemRef, {
      'currentQuantity': newQty,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    final _itemCatalog = _itemsCatalog.doc(item.id);
    batch.update(_itemCatalog, {'totalQuantity': FieldValue.increment(delta), 'updatedAt': DateTime.now().toIso8601String()});

    final logRef = _logs(buildingId, floorId, roomId).doc();
    batch.set(
        logRef,
        StockLog(
          itemId: item.id!,
          itemName: item.name,
          type: actualDelta > 0 ? 'increase' : 'decrease',
          quantity: actualDelta.abs(),
          previousQty: previousQty,
          newQty: newQty,
          note: note,
          buildingName: buildingName,
          floorName: floorName,
          roomName: roomName,
        ).toFirestore());

    await batch.commit();
  }

  // ── LOGS ──────────────────────────────────────────────────────────────────

  @override
  Stream<List<StockLog>> watchLogs(
      String buildingId, String floorId, String roomId,
      {String? itemId}) {
    Query q = _logs(buildingId, floorId, roomId)
        .orderBy('timestamp', descending: true)
        .limit(200);
    if (itemId != null) q = q.where('itemId', isEqualTo: itemId);
    return q.snapshots().map((s) => s.docs
        .map((d) => StockLog.fromFirestore(
        d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  @override
  Stream<List<StockLog>> watchAllLogs() =>
      _db.collectionGroup('stockLogs')
          .orderBy('timestamp', descending: true)
          .limit(300)
          .snapshots()
          .map((s) => s.docs
              .map((d) => StockLog.fromFirestore(
                  d.id, d.data() as Map<String, dynamic>))
              .toList());

  @override
  Future<int> migrateStockLogsLocation() async {
    int migrated = 0;
    final buildingsSnap = await _buildings.get();
    for (final bDoc in buildingsSnap.docs) {
      final buildingName = (bDoc.data() as Map<String, dynamic>)['name'] ?? '';
      final floorsSnap = await _floors(bDoc.id).get();
      for (final fDoc in floorsSnap.docs) {
        final floorName = (fDoc.data() as Map<String, dynamic>)['name'] ?? '';
        final roomsSnap = await _rooms(bDoc.id, fDoc.id).get();
        for (final rDoc in roomsSnap.docs) {
          final roomName = (rDoc.data() as Map<String, dynamic>)['name'] ?? '';
          final logsSnap = await _logs(bDoc.id, fDoc.id, rDoc.id).get();
          for (final lDoc in logsSnap.docs) {
            final data = lDoc.data() as Map<String, dynamic>;
            if (data['buildingName'] == null || data['buildingName'] == '') {
              await lDoc.reference.update({
                'buildingName': buildingName,
                'floorName': floorName,
                'roomName': roomName,
              });
              migrated++;
            }
          }
        }
      }
    }
    return migrated;
  }

  // ── INSPECTIONS ───────────────────────────────────────────────────────────

  @override
  Stream<List<InspectionModel>> watchInspections(
      String buildingId, String floorId, String roomId) =>
      _inspections(buildingId, floorId, roomId)
          .orderBy('startedAt', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs
          .map((d) => InspectionModel.fromFirestore(
          d.id, d.data() as Map<String, dynamic>))
          .toList());

  /// Creates a new in-progress inspection, snapshotting current item quantities.
  @override
  Future<String> startInspection({
    required BuildingModel building,
    required FloorModel floor,
    required RoomModel room,
    required List<StockItem> currentItems,
  }) async {
    final checklist = currentItems
        .map((item) => InspectionChecklistItem(
      itemId: item.id!,
      itemName: item.name,
      expectedQty: item.currentQuantity,
      actualQty: item.currentQuantity, // pre-fill as expected
      matched: true,
    ))
        .toList();

    final inspection = InspectionModel(
      roomId: room.id!,
      roomName: room.name,
      floorId: floor.id!,
      floorName: floor.name,
      buildingId: building.id!,
      buildingName: building.name,
      status: 'in_progress',
      checklistItems: checklist,
    );

    final doc = await _inspections(building.id!, floor.id!, room.id!)
        .add(inspection.toFirestore());
    return doc.id;
  }

  /// Saves updated checklist progress (called while editing).
  @override
  Future<void> updateInspectionChecklist({
    required String buildingId,
    required String floorId,
    required String roomId,
    required String inspectionId,
    required List<InspectionChecklistItem> checklistItems,
    required String overallNote,
  }) async {
    final hasDiscrepancy = checklistItems.any((e) => !e.matched);
    await _inspections(buildingId, floorId, roomId)
        .doc(inspectionId)
        .update({
      'checklistItems': checklistItems.map((e) => e.toMap()).toList(),
      'overallNote': overallNote,
      'hasDiscrepancy': hasDiscrepancy,
    });
  }

  /// Completes an inspection.  Optionally syncs quantities to actual counts.
  @override
  Future<void> completeInspection({
    required BuildingModel building,
    required FloorModel floor,
    required RoomModel room,
    required InspectionModel inspection,
    required bool syncQuantities,
  }) async {
    final now = DateTime.now();
    final batch = _db.batch();

    // Mark inspection complete
    final inspRef =
    _inspections(building.id!, floor.id!, room.id!).doc(inspection.id);
    batch.update(inspRef, {
      'status': 'completed',
      'completedAt': now.toIso8601String(),
      'checklistItems':
      inspection.checklistItems.map((e) => e.toMap()).toList(),
      'hasDiscrepancy': inspection.hasDiscrepancy,
      'overallNote': inspection.overallNote,
    });

    // If syncing, adjust quantities for mismatched items
    if (syncQuantities) {
      for (final ci in inspection.checklistItems) {
        if (ci.matched) continue;
        final delta = ci.actualQty - ci.expectedQty;
        if (delta == 0) continue;

        final itemRef =
        _items(building.id!, floor.id!, room.id!).doc(ci.itemId);
        batch.update(itemRef, {
          'currentQuantity': ci.actualQty,
          'updatedAt': now.toIso8601String(),
        });

        final logRef = _logs(building.id!, floor.id!, room.id!).doc();
        batch.set(logRef, StockLog(
          itemId: ci.itemId,
          itemName: ci.itemName,
          type: delta > 0 ? 'increase' : 'decrease',
          quantity: delta.abs(),
          previousQty: ci.expectedQty,
          newQty: ci.actualQty,
          note: 'Corrected during inspection #${inspection.id}',
          timestamp: now,
          buildingName: building.name,
          floorName: floor.name,
          roomName: room.name,
        ).toFirestore());
      }
    }

    await batch.commit();
  }

  // ── STOCK TRANSFER ────────────────────────────────────────────────────────

  /// Atomically moves [quantity] units of [item] from one room to another.
  @override
  Future<void> transferItem({
    required BuildingModel fromBuilding,
    required FloorModel fromFloor,
    required RoomModel fromRoom,
    required BuildingModel toBuilding,
    required FloorModel toFloor,
    required RoomModel toRoom,
    required StockItem item,
    required int quantity,
    required String note,
  }) async {
    if (quantity <= 0) return;
    final clamped = quantity.clamp(0, item.currentQuantity);
    if (clamped == 0) return;

    final now = DateTime.now();
    final batch = _db.batch();

    // Decrease source
    final fromItemRef =
    _items(fromBuilding.id!, fromFloor.id!, fromRoom.id!).doc(item.id);
    final newFromQty = item.currentQuantity - clamped;
    batch.update(fromItemRef, {
      'currentQuantity': newFromQty,
      'updatedAt': now.toIso8601String(),
    });

    // Increase destination — find or create the item there
    // We write a new item doc with the same name/price under the destination room
    final toItemRef =
    _items(toBuilding.id!, toFloor.id!, toRoom.id!).doc(item.id);
    // Use set with merge so quantity adds on top of any existing value
    batch.set(
      toItemRef,
      {
        'name': item.name,
        'unitPrice': item.unitPrice,
        'currentQuantity': FieldValue.increment(clamped),
        'createdAt': item.createdAt?.toIso8601String() ??
            now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      },
      SetOptions(merge: true),
    );

    // Source log
    final fromLogRef =
    _logs(fromBuilding.id!, fromFloor.id!, fromRoom.id!).doc();
    batch.set(fromLogRef, StockLog(
      itemId: item.id!,
      itemName: item.name,
      type: 'decrease',
      quantity: clamped,
      previousQty: item.currentQuantity,
      newQty: newFromQty,
      note: 'Transferred to ${toRoom.name}, ${toFloor.name}, '
          '${toBuilding.name}. $note',
      timestamp: now,
      buildingName: fromBuilding.name,
      floorName: fromFloor.name,
      roomName: fromRoom.name,
    ).toFirestore());

    // Destination log
    final toLogRef =
    _logs(toBuilding.id!, toFloor.id!, toRoom.id!).doc();
    batch.set(toLogRef, StockLog(
      itemId: item.id!,
      itemName: item.name,
      type: 'increase',
      quantity: clamped,
      previousQty: 0,
      newQty: clamped,
      note: 'Transferred from ${fromRoom.name}, ${fromFloor.name}, '
          '${fromBuilding.name}. $note',
      timestamp: now,
      buildingName: toBuilding.name,
      floorName: toFloor.name,
      roomName: toRoom.name,
    ).toFirestore());

    // Transfer record
    final transferRef = _transfers.doc();
    batch.set(
        transferRef,
        StockTransfer(
          fromBuildingId: fromBuilding.id!,
          fromBuildingName: fromBuilding.name,
          fromFloorId: fromFloor.id!,
          fromFloorName: fromFloor.name,
          fromRoomId: fromRoom.id!,
          fromRoomName: fromRoom.name,
          toBuildingId: toBuilding.id!,
          toBuildingName: toBuilding.name,
          toFloorId: toFloor.id!,
          toFloorName: toFloor.name,
          toRoomId: toRoom.id!,
          toRoomName: toRoom.name,
          itemId: item.id!,
          itemName: item.name,
          quantity: clamped,
          note: note,
          transferredAt: now,
        ).toFirestore());

    await batch.commit();
  }

  // ── CONSUMABLE ASSIGNMENTS ────────────────────────────────────────────────

  @override
  Stream<List<ConsumableAssignment>> watchAssignments({
    String? itemId,
    String? roomId,
  }) {
    // Use a single equality filter to avoid composite index requirements.
    // Prefer the most selective filter available, then narrow client-side.
    Query q;
    if (itemId != null) {
      q = _assignments.where('itemId', isEqualTo: itemId);
    } else if (roomId != null) {
      q = _assignments.where('roomId', isEqualTo: roomId);
    } else {
      q = _assignments.where('status', isEqualTo: 'active');
    }

    return q.snapshots().map((s) {
      final all = s.docs
          .map((d) => ConsumableAssignment.fromFirestore(
          d.id, d.data() as Map<String, dynamic>))
          .toList();

      // Filter client-side — no composite index needed
      var result = all.where((a) => a.status == 'active').toList();
      if (itemId != null) {
        result = result.where((a) => a.itemId == itemId).toList();
      }
      if (roomId != null) {
        result = result.where((a) => a.roomId == roomId).toList();
      }

      // Sort newest first
      result.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
      return result;
    });
  }

  @override
  Stream<List<ConsumableAssignment>> watchAllAssignments() =>
      _assignments
          .limit(200)
          .snapshots()
          .map((s) {
        final list = s.docs
            .map((d) => ConsumableAssignment.fromFirestore(
            d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
        return list;
      });

  /// Assigns consumable stock to a staff member (decreases room quantity).
  @override
  Future<void> assignConsumable({
    required BuildingModel building,
    required FloorModel floor,
    required RoomModel room,
    required StockItem item,
    required int quantity,
    required String assignedTo,
    required String note,
  }) async {
    if (quantity <= 0 || quantity > item.currentQuantity) return;

    final now = DateTime.now();
    final batch = _db.batch();

    // Decrease item quantity
    final itemRef =
    _items(building.id!, floor.id!, room.id!).doc(item.id);
    final newQty = item.currentQuantity - quantity;
    batch.update(itemRef, {
      'currentQuantity': newQty,
      'updatedAt': now.toIso8601String(),
    });

    // Stock log
    final logRef = _logs(building.id!, floor.id!, room.id!).doc();
    batch.set(logRef, StockLog(
      itemId: item.id!,
      itemName: item.name,
      type: 'decrease',
      quantity: quantity,
      previousQty: item.currentQuantity,
      newQty: newQty,
      note: 'Assigned to $assignedTo. $note',
      timestamp: now,
      buildingName: building.name,
      floorName: floor.name,
      roomName: room.name,
    ).toFirestore());

    // Assignment record
    final assignRef = _assignments.doc();
    batch.set(
        assignRef,
        ConsumableAssignment(
          roomId: room.id!,
          roomName: room.name,
          buildingId: building.id!,
          floorId: floor.id!,
          itemId: item.id!,
          itemName: item.name,
          quantity: quantity,
          assignedTo: assignedTo,
          assignedAt: now,
          status: 'active',
          note: note,
        ).toFirestore());

    await batch.commit();
  }

  /// Returns consumable stock from a staff member (increases room quantity).
  @override
  Future<void> returnConsumable({
    required BuildingModel building,
    required FloorModel floor,
    required RoomModel room,
    required StockItem item,
    required ConsumableAssignment assignment,
    required int returnQty,
  }) async {
    if (returnQty <= 0 || returnQty > assignment.outstandingQty) return;

    final now = DateTime.now();
    final batch = _db.batch();

    // Increase item quantity
    final itemRef =
    _items(building.id!, floor.id!, room.id!).doc(item.id);
    final newQty = item.currentQuantity + returnQty;
    batch.update(itemRef, {
      'currentQuantity': newQty,
      'updatedAt': now.toIso8601String(),
    });

    // Stock log
    final logRef = _logs(building.id!, floor.id!, room.id!).doc();
    batch.set(logRef, StockLog(
      itemId: item.id!,
      itemName: item.name,
      type: 'increase',
      quantity: returnQty,
      previousQty: item.currentQuantity,
      newQty: newQty,
      note: 'Returned by ${assignment.assignedTo}',
      timestamp: now,
      buildingName: building.name,
      floorName: floor.name,
      roomName: room.name,
    ).toFirestore());

    // Update assignment
    final newReturnedQty = assignment.returnedQty + returnQty;
    final isFullReturn = newReturnedQty >= assignment.quantity;
    final assignRef = _assignments.doc(assignment.id);
    batch.update(assignRef, {
      'returnedQty': newReturnedQty,
      'returnedAt': now.toIso8601String(),
      'status':
      isFullReturn ? 'returned' : 'partially_returned',
    });

    await batch.commit();
  }
}