import 'package:gd_college/utils/timestamps.dart';

// ── Building ──────────────────────────────────────────────────────────────────
class BuildingModel {
  String? id;
  String name;
  DateTime? createdAt;

  BuildingModel({this.id, this.name = '', this.createdAt});

  factory BuildingModel.fromFirestore(String id, Map<String, dynamic> d) =>
      BuildingModel(
        id: id,
        name: d['name'] ?? '',
        createdAt:
        parseTimestamp(d['createdAt']),
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'createdAt': timestampToWire(createdAt),
  };
}

// ── Floor ─────────────────────────────────────────────────────────────────────
class FloorModel {
  String? id;
  String name;
  String buildingId;
  DateTime? createdAt;

  FloorModel(
      {this.id, this.name = '', this.buildingId = '', this.createdAt});

  factory FloorModel.fromFirestore(String id, Map<String, dynamic> d) =>
      FloorModel(
        id: id,
        name: d['name'] ?? '',
        buildingId: d['buildingId'] ?? '',
        createdAt:
        parseTimestamp(d['createdAt']),
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'buildingId': buildingId,
    'createdAt': timestampToWire(createdAt),
  };
}

// ── Room ──────────────────────────────────────────────────────────────────────
class RoomModel {
  String? id;
  String name;
  String floorId;
  String buildingId;
  List<String> photoUrls;
  List<String> videoUrls;
  DateTime? createdAt;
  // Feature: Media Freshness
  DateTime? lastMediaUploadedAt;
  // Feature: Inspection Tracking
  DateTime? lastInspectedAt;

  RoomModel({
    this.id,
    this.name = '',
    this.floorId = '',
    this.buildingId = '',
    this.photoUrls = const [],
    this.videoUrls = const [],
    this.createdAt,
    this.lastMediaUploadedAt,
    this.lastInspectedAt,
  });

  /// Returns true if no media has been uploaded or last upload was >30 days ago.
  bool get isMediaOverdue {
    if (lastMediaUploadedAt == null) return true;
    return DateTime.now().difference(lastMediaUploadedAt!).inDays > 30;
  }

  /// Returns true if the room has never been inspected or last inspection
  /// was more than 14 days ago.
  bool get isInspectionDue {
    if (lastInspectedAt == null) return true;
    return DateTime.now().difference(lastInspectedAt!).inDays > 14;
  }

  factory RoomModel.fromFirestore(String id, Map<String, dynamic> d) =>
      RoomModel(
        id: id,
        name: d['name'] ?? '',
        floorId: d['floorId'] ?? '',
        buildingId: d['buildingId'] ?? '',
        photoUrls: List<String>.from(d['photoUrls'] ?? []),
        videoUrls: List<String>.from(d['videoUrls'] ?? []),
        createdAt:
        parseTimestamp(d['createdAt']),
        lastMediaUploadedAt: parseTimestamp(d['lastMediaUploadedAt']),
        lastInspectedAt: parseTimestamp(d['lastInspectedAt']),
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'floorId': floorId,
    'buildingId': buildingId,
    'photoUrls': photoUrls,
    'videoUrls': videoUrls,
    'createdAt': timestampToWire(createdAt),
    'lastMediaUploadedAt': timestampToWire(lastMediaUploadedAt),
    'lastInspectedAt': timestampToWire(lastInspectedAt),
  };
}

// ── Stock Item ────────────────────────────────────────────────────────────────
class StockItem {
  String? id;
  String name;
  double unitPrice;
  int currentQuantity;
  DateTime? createdAt;
  DateTime? updatedAt;
  String store;
  String bill;
  String unit; // 'Pieces', 'kg', 'gram', 'metre', 'litres', ...
  String sourceBillId; // bill that originally added this item to a room

  StockItem({
    this.id,
    this.name = '',
    this.unitPrice = 0,
    this.currentQuantity = 0,
    this.store = '',
    this.bill = '',
    this.unit = 'Pieces',
    this.sourceBillId = '',
    this.createdAt,
    this.updatedAt,
  });

  double get totalValue => unitPrice * currentQuantity;

  factory StockItem.fromFirestore(String id, Map<String, dynamic> d) =>
      StockItem(
        id: id,
        name: d['name'] ?? '',
        unitPrice: (d['unitPrice'] ?? 0).toDouble(),
        currentQuantity: d['currentQuantity'] ?? 0,
        createdAt:
        parseTimestamp(d['createdAt']),
        updatedAt:
        parseTimestamp(d['updatedAt']),
        store: d['store'] ?? '',
        bill: d['bill'] ?? '',
        unit: d['unit'] ?? 'Pieces',
        sourceBillId: d['sourceBillId'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'unitPrice': unitPrice,
    'currentQuantity': currentQuantity,
    'createdAt': timestampToWire(createdAt),
    'updatedAt': timestampToWire(updatedAt),
    'store': store,
    'bill': bill,
    'unit': unit,
    'sourceBillId': sourceBillId,
  };
}

// ── Catalog location / price-history read models ─────────────────────────────

/// Where and how many of a catalog item a single room currently stocks.
class ItemLocationStock {
  final String buildingName;
  final String floorName;
  final String roomName;
  final int quantity;

  ItemLocationStock({
    required this.buildingName,
    required this.floorName,
    required this.roomName,
    required this.quantity,
  });
}

/// One room-level item with its parent ids resolved from the doc path
/// (buildings/{b}/floors/{f}/rooms/{r}/items/{id}). Item docs carry no
/// parent refs, so consolidation readers derive location from the path.
class ScopedStockItem {
  final String buildingId;
  final String floorId;
  final String roomId;
  final StockItem item;

  const ScopedStockItem({
    required this.buildingId,
    required this.floorId,
    required this.roomId,
    required this.item,
  });
}

/// One purchase/adjustment entry from an item's price history.
class ItemPriceLog {
  final DateTime timestamp;
  final double price;

  /// Magnitude of the quantity change; see [type] for the direction.
  final int quantity;
  final String store;
  final String bill;

  /// 'increase' or 'decrease'.
  final String type;

  ItemPriceLog({
    required this.timestamp,
    required this.price,
    required this.quantity,
    required this.store,
    required this.bill,
    this.type = 'increase',
  });
}

class CatalogItem {
  String? id;
  String name;
  double lastPrice;
  int totalQuantity;
  String? photoUrl;
  DateTime? createdAt;
  DateTime? updatedAt;

  CatalogItem({
    this.id,
    this.name = '',
    this.lastPrice = 0,
    this.totalQuantity = 0,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory CatalogItem.fromFirestore(String id, Map<String, dynamic> d) =>
      CatalogItem(
        id: id,
        name: d['name'] ?? '',
        lastPrice: (d['lastPrice'] ?? 0).toDouble(),
        totalQuantity: d['totalQuantity'] ?? 0,
        photoUrl: d['photoUrl'],
        createdAt:
        parseTimestamp(d['createdAt']),
        updatedAt:
        parseTimestamp(d['updatedAt']),
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'lastPrice': lastPrice,
    'totalQuantity': totalQuantity,
    'photoUrl': photoUrl,
    'createdAt': timestampToWire(createdAt),
    'updatedAt': timestampToWire(updatedAt),
  };
}


// ── Stock Log ─────────────────────────────────────────────────────────────────
class StockLog {
  String? id;
  String itemId;
  String itemName;
  String type; // 'increase' | 'decrease' | 'inspection' | 'photo'
  int quantity;
  int previousQty;
  int newQty;
  String note;
  DateTime timestamp;
  String buildingName;
  String floorName;
  String roomName;
  String changedBy;
  String? inspectionId; // set when type == 'inspection'
  String? oldPhotoUrl; // set when type == 'photo'
  String? newPhotoUrl; // set when type == 'photo'

  StockLog({
    this.id,
    this.itemId = '',
    this.itemName = '',
    this.type = 'increase',
    this.quantity = 0,
    this.previousQty = 0,
    this.newQty = 0,
    this.note = '',
    DateTime? timestamp,
    this.buildingName = '',
    this.floorName = '',
    this.roomName = '',
    this.changedBy = '',
    this.inspectionId,
    this.oldPhotoUrl,
    this.newPhotoUrl,
  }) : timestamp = timestamp ?? DateTime.now();

  factory StockLog.fromFirestore(String id, Map<String, dynamic> d) =>
      StockLog(
        id: id,
        itemId: d['itemId'] ?? '',
        itemName: d['itemName'] ?? '',
        type: d['type'] ?? 'increase',
        quantity: d['quantity'] ?? 0,
        previousQty: d['previousQty'] ?? 0,
        newQty: d['newQty'] ?? 0,
        note: d['note'] ?? '',
        timestamp: parseTimestamp(d['timestamp']) ?? DateTime.now(),
        buildingName: d['buildingName'] ?? '',
        floorName: d['floorName'] ?? '',
        roomName: d['roomName'] ?? '',
        changedBy: d['changedBy'] ?? '',
        inspectionId: d['inspectionId'],
        oldPhotoUrl: d['oldPhotoUrl'],
        newPhotoUrl: d['newPhotoUrl'],
      );

  Map<String, dynamic> toFirestore() => {
    'itemId': itemId,
    'itemName': itemName,
    'type': type,
    'quantity': quantity,
    'previousQty': previousQty,
    'newQty': newQty,
    'note': note,
    'timestamp': timestampToWire(timestamp),
    'buildingName': buildingName,
    'floorName': floorName,
    'roomName': roomName,
    'changedBy': changedBy,
    if (inspectionId != null) 'inspectionId': inspectionId,
    if (oldPhotoUrl != null) 'oldPhotoUrl': oldPhotoUrl,
    if (newPhotoUrl != null) 'newPhotoUrl': newPhotoUrl,
  };
}

// ── Inspection ────────────────────────────────────────────────────────────────

class InspectionChecklistItem {
  String itemId;
  String itemName;
  int expectedQty;
  int actualQty;
  bool matched;
  String note;

  InspectionChecklistItem({
    this.itemId = '',
    this.itemName = '',
    this.expectedQty = 0,
    this.actualQty = 0,
    this.matched = false,
    this.note = '',
  });

  factory InspectionChecklistItem.fromMap(Map<String, dynamic> d) =>
      InspectionChecklistItem(
        itemId: d['itemId'] ?? '',
        itemName: d['itemName'] ?? '',
        expectedQty: d['expectedQty'] ?? 0,
        actualQty: d['actualQty'] ?? 0,
        matched: d['matched'] ?? false,
        note: d['note'] ?? '',
      );

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    'expectedQty': expectedQty,
    'actualQty': actualQty,
    'matched': matched,
    'note': note,
  };
}

class InspectionModel {
  String? id;
  String roomId;
  String roomName;
  String floorId;
  String floorName;
  String buildingId;
  String buildingName;
  DateTime startedAt;
  DateTime? completedAt;
  String status; // 'in_progress' | 'completed'
  String overallNote;
  bool hasDiscrepancy;
  bool mediaUploaded;
  List<InspectionChecklistItem> checklistItems;

  InspectionModel({
    this.id,
    this.roomId = '',
    this.roomName = '',
    this.floorId = '',
    this.floorName = '',
    this.buildingId = '',
    this.buildingName = '',
    DateTime? startedAt,
    this.completedAt,
    this.status = 'in_progress',
    this.overallNote = '',
    this.hasDiscrepancy = false,
    this.mediaUploaded = false,
    this.checklistItems = const [],
  }) : startedAt = startedAt ?? DateTime.now();

  Duration? get duration =>
      completedAt != null ? completedAt!.difference(startedAt) : null;

  factory InspectionModel.fromFirestore(
      String id, Map<String, dynamic> d) =>
      InspectionModel(
        id: id,
        roomId: d['roomId'] ?? '',
        roomName: d['roomName'] ?? '',
        floorId: d['floorId'] ?? '',
        floorName: d['floorName'] ?? '',
        buildingId: d['buildingId'] ?? '',
        buildingName: d['buildingName'] ?? '',
        startedAt: parseTimestamp(d['startedAt']) ?? DateTime.now(),
        completedAt: parseTimestamp(d['completedAt']),
        status: d['status'] ?? 'in_progress',
        overallNote: d['overallNote'] ?? '',
        hasDiscrepancy: d['hasDiscrepancy'] ?? false,
        mediaUploaded: d['mediaUploaded'] ?? false,
        checklistItems: (d['checklistItems'] as List<dynamic>? ?? [])
            .map((e) =>
            InspectionChecklistItem.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toFirestore() => {
    'roomId': roomId,
    'roomName': roomName,
    'floorId': floorId,
    'floorName': floorName,
    'buildingId': buildingId,
    'buildingName': buildingName,
    'startedAt': timestampToWire(startedAt),
    'completedAt': timestampToWire(completedAt),
    'status': status,
    'overallNote': overallNote,
    'hasDiscrepancy': hasDiscrepancy,
    'mediaUploaded': mediaUploaded,
    'checklistItems': checklistItems.map((e) => e.toMap()).toList(),
  };
}

// ── Stock Transfer ────────────────────────────────────────────────────────────

class StockTransfer {
  String? id;
  String fromBuildingId;
  String fromBuildingName;
  String fromFloorId;
  String fromFloorName;
  String fromRoomId;
  String fromRoomName;
  String toBuildingId;
  String toBuildingName;
  String toFloorId;
  String toFloorName;
  String toRoomId;
  String toRoomName;
  String itemId;
  String itemName;
  int quantity;
  String note;
  DateTime transferredAt;

  StockTransfer({
    this.id,
    this.fromBuildingId = '',
    this.fromBuildingName = '',
    this.fromFloorId = '',
    this.fromFloorName = '',
    this.fromRoomId = '',
    this.fromRoomName = '',
    this.toBuildingId = '',
    this.toBuildingName = '',
    this.toFloorId = '',
    this.toFloorName = '',
    this.toRoomId = '',
    this.toRoomName = '',
    this.itemId = '',
    this.itemName = '',
    this.quantity = 0,
    this.note = '',
    DateTime? transferredAt,
  }) : transferredAt = transferredAt ?? DateTime.now();

  factory StockTransfer.fromFirestore(
      String id, Map<String, dynamic> d) =>
      StockTransfer(
        id: id,
        fromBuildingId: d['fromBuildingId'] ?? '',
        fromBuildingName: d['fromBuildingName'] ?? '',
        fromFloorId: d['fromFloorId'] ?? '',
        fromFloorName: d['fromFloorName'] ?? '',
        fromRoomId: d['fromRoomId'] ?? '',
        fromRoomName: d['fromRoomName'] ?? '',
        toBuildingId: d['toBuildingId'] ?? '',
        toBuildingName: d['toBuildingName'] ?? '',
        toFloorId: d['toFloorId'] ?? '',
        toFloorName: d['toFloorName'] ?? '',
        toRoomId: d['toRoomId'] ?? '',
        toRoomName: d['toRoomName'] ?? '',
        itemId: d['itemId'] ?? '',
        itemName: d['itemName'] ?? '',
        quantity: d['quantity'] ?? 0,
        note: d['note'] ?? '',
        transferredAt: parseTimestamp(d['transferredAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
    'fromBuildingId': fromBuildingId,
    'fromBuildingName': fromBuildingName,
    'fromFloorId': fromFloorId,
    'fromFloorName': fromFloorName,
    'fromRoomId': fromRoomId,
    'fromRoomName': fromRoomName,
    'toBuildingId': toBuildingId,
    'toBuildingName': toBuildingName,
    'toFloorId': toFloorId,
    'toFloorName': toFloorName,
    'toRoomId': toRoomId,
    'toRoomName': toRoomName,
    'itemId': itemId,
    'itemName': itemName,
    'quantity': quantity,
    'note': note,
    'transferredAt': timestampToWire(transferredAt),
  };
}

// ── Consumable Assignment ─────────────────────────────────────────────────────

class ConsumableAssignment {
  String? id;
  String roomId;
  String roomName;
  String buildingId;
  String floorId;
  String itemId;
  String itemName;
  int quantity;
  String assignedTo;
  DateTime assignedAt;
  DateTime? returnedAt;
  int returnedQty;
  String status; // 'active' | 'returned' | 'partially_returned'
  String note;

  ConsumableAssignment({
    this.id,
    this.roomId = '',
    this.roomName = '',
    this.buildingId = '',
    this.floorId = '',
    this.itemId = '',
    this.itemName = '',
    this.quantity = 0,
    this.assignedTo = '',
    DateTime? assignedAt,
    this.returnedAt,
    this.returnedQty = 0,
    this.status = 'active',
    this.note = '',
  }) : assignedAt = assignedAt ?? DateTime.now();

  int get outstandingQty => quantity - returnedQty;

  factory ConsumableAssignment.fromFirestore(
      String id, Map<String, dynamic> d) =>
      ConsumableAssignment(
        id: id,
        roomId: d['roomId'] ?? '',
        roomName: d['roomName'] ?? '',
        buildingId: d['buildingId'] ?? '',
        floorId: d['floorId'] ?? '',
        itemId: d['itemId'] ?? '',
        itemName: d['itemName'] ?? '',
        quantity: d['quantity'] ?? 0,
        assignedTo: d['assignedTo'] ?? '',
        assignedAt: parseTimestamp(d['assignedAt']) ?? DateTime.now(),
        returnedAt: parseTimestamp(d['returnedAt']),
        returnedQty: d['returnedQty'] ?? 0,
        status: d['status'] ?? 'active',
        note: d['note'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'roomId': roomId,
    'roomName': roomName,
    'buildingId': buildingId,
    'floorId': floorId,
    'itemId': itemId,
    'itemName': itemName,
    'quantity': quantity,
    'assignedTo': assignedTo,
    'assignedAt': timestampToWire(assignedAt),
    'returnedAt': timestampToWire(returnedAt),
    'returnedQty': returnedQty,
    'status': status,
    'note': note,
  };
}