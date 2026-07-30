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
        d['createdAt'] != null ? DateTime.tryParse(d['createdAt']) : null,
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'createdAt': createdAt?.toIso8601String(),
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
        d['createdAt'] != null ? DateTime.tryParse(d['createdAt']) : null,
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'buildingId': buildingId,
    'createdAt': createdAt?.toIso8601String(),
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
        d['createdAt'] != null ? DateTime.tryParse(d['createdAt']) : null,
        lastMediaUploadedAt: d['lastMediaUploadedAt'] != null
            ? DateTime.tryParse(d['lastMediaUploadedAt'])
            : null,
        lastInspectedAt: d['lastInspectedAt'] != null
            ? DateTime.tryParse(d['lastInspectedAt'])
            : null,
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'floorId': floorId,
    'buildingId': buildingId,
    'photoUrls': photoUrls,
    'videoUrls': videoUrls,
    'createdAt': createdAt?.toIso8601String(),
    'lastMediaUploadedAt': lastMediaUploadedAt?.toIso8601String(),
    'lastInspectedAt': lastInspectedAt?.toIso8601String(),
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

  StockItem({
    this.id,
    this.name = '',
    this.unitPrice = 0,
    this.currentQuantity = 0,
    this.store = '',
    this.bill = '',
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
        d['createdAt'] != null ? DateTime.tryParse(d['createdAt']) : null,
        updatedAt:
        d['updatedAt'] != null ? DateTime.tryParse(d['updatedAt']) : null,
        store: d['store'] ?? '',
        bill: d['bill'] ?? '',
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'unitPrice': unitPrice,
    'currentQuantity': currentQuantity,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'store': store,
    'bill': bill,
  };
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
        d['createdAt'] != null ? DateTime.tryParse(d['createdAt']) : null,
        updatedAt:
        d['updatedAt'] != null ? DateTime.tryParse(d['updatedAt']) : null,
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'lastPrice': lastPrice,
    'totalQuantity': totalQuantity,
    'photoUrl': photoUrl,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}


// ── Stock Log ─────────────────────────────────────────────────────────────────
class StockLog {
  String? id;
  String itemId;
  String itemName;
  String type; // 'increase' | 'decrease' | 'inspection'
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
        timestamp: d['timestamp'] != null
            ? DateTime.tryParse(d['timestamp']) ?? DateTime.now()
            : DateTime.now(),
        buildingName: d['buildingName'] ?? '',
        floorName: d['floorName'] ?? '',
        roomName: d['roomName'] ?? '',
        changedBy: d['changedBy'] ?? '',
        inspectionId: d['inspectionId'],
      );

  Map<String, dynamic> toFirestore() => {
    'itemId': itemId,
    'itemName': itemName,
    'type': type,
    'quantity': quantity,
    'previousQty': previousQty,
    'newQty': newQty,
    'note': note,
    'timestamp': timestamp.toIso8601String(),
    'buildingName': buildingName,
    'floorName': floorName,
    'roomName': roomName,
    'changedBy': changedBy,
    if (inspectionId != null) 'inspectionId': inspectionId,
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
        startedAt: d['startedAt'] != null
            ? DateTime.tryParse(d['startedAt']) ?? DateTime.now()
            : DateTime.now(),
        completedAt: d['completedAt'] != null
            ? DateTime.tryParse(d['completedAt'])
            : null,
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
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
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
        transferredAt: d['transferredAt'] != null
            ? DateTime.tryParse(d['transferredAt']) ?? DateTime.now()
            : DateTime.now(),
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
    'transferredAt': transferredAt.toIso8601String(),
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
        assignedAt: d['assignedAt'] != null
            ? DateTime.tryParse(d['assignedAt']) ?? DateTime.now()
            : DateTime.now(),
        returnedAt: d['returnedAt'] != null
            ? DateTime.tryParse(d['returnedAt'])
            : null,
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
    'assignedAt': assignedAt.toIso8601String(),
    'returnedAt': returnedAt?.toIso8601String(),
    'returnedQty': returnedQty,
    'status': status,
    'note': note,
  };
}