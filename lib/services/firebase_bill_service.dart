import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../bill_management/models/bill_models.dart';
import '../models/user_session.dart';
import '../repositories/bill_repository.dart';
import '../repositories/stock_repository.dart';
import '../stock_management/models/stock_models.dart';

class FirebaseBillRepository implements BillRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final StockRepository _stock;

  FirebaseBillRepository({required StockRepository stockRepository})
      : _stock = stockRepository;

  CollectionReference<Map<String, dynamic>> get _bills =>
      _db.collection('bills');

  CollectionReference<Map<String, dynamic>> get _billLogs =>
      _db.collection('billLogs');

  String get _currentUser => UserSession().currentUser?.email ?? '';

  @override
  Stream<List<BillModel>> watchBills() => _bills
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
      .map((d) => BillModel.fromFirestore(d.id, d.data()))
      .toList());

  @override
  Stream<List<BillLog>> watchAllBillLogs() => _billLogs
      .orderBy('timestamp', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs
      .map((d) => BillLog.fromFirestore(d.id, d.data()))
      .toList());

  @override
  Future<String> createBill(
      BillModel bill, {
        Uint8List? photoBytes,
        String? photoName,
      }) async {
    final now = DateTime.now();
    final docRef = _bills.doc(); // pre-generate the id for storage paths
    bill.id = docRef.id;
    bill.createdAt = now;
    bill.updatedAt = now;
    bill.createdBy = _currentUser;
    bill.updatedBy = _currentUser;

    if (photoBytes != null && photoName != null) {
      bill.photoUrl = await _uploadPhoto(docRef.id, photoBytes, photoName);
    }

    await docRef.set(bill.toFirestore());
    await _syncBillItemsToPending(bill, updateMode: false);
    await _writeLog(docRef.id, bill.billNumber, 'create',
        'Bill created. ${bill.items.length} item(s), total '
            '₹${bill.totalAmount.toStringAsFixed(2)}.');
    return docRef.id;
  }

  @override
  Future<void> updateBill(
      BillModel bill, {
        Uint8List? photoBytes,
        String? photoName,
        bool removePhoto = false,
      }) async {
    final now = DateTime.now();
    final id = bill.id;
    if (id == null) return;

    bill.updatedAt = now;
    bill.updatedBy = _currentUser;

    if (photoBytes != null && photoName != null) {
      bill.photoUrl = await _uploadPhoto(id, photoBytes, photoName);
    } else if (removePhoto) {
      bill.photoUrl = null;
    }

    await _bills.doc(id).set(bill.toFirestore());
    await _syncBillItemsToPending(bill, updateMode: true);
    await _writeLog(id, bill.billNumber, 'update',
        'Bill updated. ${bill.items.length} item(s), total '
            '₹${bill.totalAmount.toStringAsFixed(2)}.');
  }

  @override
  Future<void> markBillPaid(String billId) async {
    final now = DateTime.now();
    final snap = await _bills.doc(billId).get();
    final billNumber = snap.data()?['billNumber'] ?? '';

    await _bills.doc(billId).update({
      'paid': true,
      'paymentDate': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'updatedBy': _currentUser,
    });
    await _writeLog(billId, billNumber, 'pay', 'Bill marked as paid.');
  }

  // ── Photo upload ────────────────────────────────────────────────────────────

  Future<String?> _uploadPhoto(
      String billId, Uint8List bytes, String name) async {
    try {
      final ref = _storage.ref().child('bills/$billId/bill_photo${_ext(name)}');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Bill photo upload failed: $e');
      return null;
    }
  }

  String _ext(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    final ext = name.substring(dot).toLowerCase();
    return ext.length <= 5 ? ext : '.jpg';
  }

  // ── Logs ────────────────────────────────────────────────────────────────────

  Future<void> _writeLog(
      String billId, String billNumber, String action, String detail) async {
    await _billLogs.add(BillLog(
      billId: billId,
      billNumber: billNumber,
      action: action,
      changedBy: _currentUser,
      detail: detail,
    ).toFirestore());
  }

  // ── Stock integration: Extras > Pending > Pending ──────────────────────────

  /// Finds or creates the 'Extras' building > 'Pending' floor > 'Pending' room.
  Future<({String buildingId, String floorId, String roomId})>
  _ensurePendingRoom() async {
    final now = DateTime.now().toIso8601String();

    String buildingId;
    final buildings = await _db
        .collection('buildings')
        .where('name', isEqualTo: 'Extras')
        .limit(1)
        .get();
    if (buildings.docs.isEmpty) {
      buildingId = (await _db.collection('buildings').add(
          {'name': 'Extras', 'createdAt': now})).id;
    } else {
      buildingId = buildings.docs.first.id;
    }

    String floorId;
    final floors = await _db
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .where('name', isEqualTo: 'Pending')
        .limit(1)
        .get();
    if (floors.docs.isEmpty) {
      floorId = (await _db
          .collection('buildings')
          .doc(buildingId)
          .collection('floors')
          .add({'name': 'Pending', 'buildingId': buildingId, 'createdAt': now}))
          .id;
    } else {
      floorId = floors.docs.first.id;
    }

    String roomId;
    final rooms = await _db
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .doc(floorId)
        .collection('rooms')
        .where('name', isEqualTo: 'Pending')
        .limit(1)
        .get();
    if (rooms.docs.isEmpty) {
      roomId = (await _db
          .collection('buildings')
          .doc(buildingId)
          .collection('floors')
          .doc(floorId)
          .collection('rooms')
          .add({
        'name': 'Pending',
        'buildingId': buildingId,
        'floorId': floorId,
        'createdAt': now,
      }))
          .id;
    } else {
      roomId = rooms.docs.first.id;
    }

    return (buildingId: buildingId, floorId: floorId, roomId: roomId);
  }

  /// Adds (and on edit, true-ups) this bill's items in Extras > Pending >
  /// Pending. Only items that carry this bill's [sourceBillId] are ever
  /// decremented, so edits never reduce stock contributed by other bills.
  Future<void> _syncBillItemsToPending(
      BillModel bill, {required bool updateMode}) async {
    final room = await _ensurePendingRoom();
    final bid = room.buildingId, fid = room.floorId, rid = room.roomId;

    final catalog = await _stock.getCatalogItemSummaries();
    final catalogByLowerName = <String, String>{};
    for (final c in catalog) {
      catalogByLowerName[c.name.trim().toLowerCase()] = c.id!;
    }

    final roomItems = await _stock.watchItems(bid, fid, rid).first;
    final roomByKey = <String, StockItem>{};
    for (final it in roomItems) {
      if (it.id != null) roomByKey[it.id!] = it;
      roomByKey['name:${it.name.trim().toLowerCase()}'] = it;
    }

    // Merge duplicate line items within the same bill (sum quantities).
    final grouped = <String, BillItem>{};
    for (final item in bill.items) {
      if (item.quantity <= 0) continue;
      final key = item.catalogItemId ?? 'name:${item.name.trim().toLowerCase()}';
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = item;
      } else {
        existing.quantity += item.quantity;
      }
    }

    for (final entry in grouped.entries) {
      final item = entry.value;
      final catalogId = item.catalogItemId ??
          catalogByLowerName[item.name.trim().toLowerCase()];
      final roomKey = catalogId ?? entry.key;
      final roomItem = roomByKey[roomKey];

      if (roomItem == null) {
        await _stock.addItem(
          bid,
          fid,
          rid,
          StockItem(
            id: catalogId,
            name: item.name.trim(),
            unitPrice: item.pricePerUnit,
            currentQuantity: item.quantity,
            store: bill.storeName,
            bill: bill.billNumber,
            unit: item.unit,
            sourceBillId: bill.id ?? '',
          ),
          buildingName: 'Extras',
          floorName: 'Pending',
          roomName: 'Pending',
        );
        continue;
      }

      final owned = roomItem.sourceBillId == bill.id;
      var delta = item.quantity - roomItem.currentQuantity;
      if (!updateMode) delta = item.quantity;
      if (delta == 0) continue;
      if (updateMode && delta < 0 && !owned) continue;

      await _stock.adjustQuantity(
        buildingId: bid,
        floorId: fid,
        roomId: rid,
        item: roomItem,
        delta: delta,
        note: 'Bill ${bill.billNumber}',
        buildingName: 'Extras',
        floorName: 'Pending',
        roomName: 'Pending',
        unitPrice: item.pricePerUnit,
        store: bill.storeName,
        bill: bill.billNumber,
      );
    }

    if (updateMode) {
      for (final it in roomItems) {
        if (it.sourceBillId != bill.id) continue;
        final key = it.id != null ? it.id! : 'name:${it.name.trim().toLowerCase()}';
        if (grouped.containsKey(key)) continue;
        if (grouped.containsKey('name:${it.name.trim().toLowerCase()}')) continue;
        if (it.currentQuantity > 0) {
          await _stock.adjustQuantity(
            buildingId: bid,
            floorId: fid,
            roomId: rid,
            item: it,
            delta: -it.currentQuantity,
            note: 'Removed from bill ${bill.billNumber}',
            buildingName: 'Extras',
            floorName: 'Pending',
            roomName: 'Pending',
          );
        }
      }
    }
  }
}
