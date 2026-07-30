import 'package:image_picker/image_picker.dart';
import '../stock_management/models/stock_models.dart';

abstract class StockRepository {
  // ── Buildings ──
  Stream<List<BuildingModel>> watchBuildings();
  Future<String> addBuilding(String name);
  Future<void> updateBuilding(String id, String name);
  Future<void> deleteBuilding(String id);

  // ── Floors ──
  Stream<List<FloorModel>> watchFloors(String buildingId);
  Future<String> addFloor(String buildingId, String name);
  Future<void> updateFloor(String buildingId, String floorId, String name);
  Future<void> deleteFloor(String buildingId, String floorId);

  // ── Rooms ──
  Stream<List<RoomModel>> watchRooms(String buildingId, String floorId);
  Future<String> addRoom(String buildingId, String floorId, String name);
  Future<void> updateRoom(
      String buildingId, String floorId, String roomId, String name);
  Future<void> deleteRoom(String buildingId, String floorId, String roomId);

  // ── Room Media ──
  Future<String?> uploadRoomMedia({
    required XFile xfile,
    required String buildingId,
    required String floorId,
    required String roomId,
    required bool isVideo,
    void Function(double)? onProgress,
  });
  Future<void> addRoomPhoto(
      String buildingId, String floorId, String roomId, String url);
  Future<void> addRoomVideo(
      String buildingId, String floorId, String roomId, String url);
  Future<void> removeRoomPhoto(
      String buildingId, String floorId, String roomId, String url);
  Future<void> removeRoomVideo(
      String buildingId, String floorId, String roomId, String url);

  // ── Items ──
  Stream<List<StockItem>> watchItems(
      String buildingId, String floorId, String roomId);
  Future<String> addItem(
      String buildingId, String floorId, String roomId, StockItem item,
      {String buildingName = '', String floorName = '', String roomName = ''});
  Future<void> updateItem(
      String buildingId, String floorId, String roomId, StockItem item);
  Future<CatalogItem?> getCatalogItemById(String catalogItemId);
  Future<List<CatalogItem>> getCatalogItemSummaries();
  Future<void> deleteItem(
      String buildingId, String floorId, String roomId, String itemId);

  // ── Quantity Adjustment ──
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
  });

  // ── Logs ──
  Stream<List<StockLog>> watchLogs(
      String buildingId, String floorId, String roomId,
      {String? itemId});
  Stream<List<StockLog>> watchAllLogs();
  Future<int> migrateStockLogsLocation();

  // ── Inspections ──
  Stream<List<InspectionModel>> watchInspections(
      String buildingId, String floorId, String roomId);
  Future<String> startInspection({
    required BuildingModel building,
    required FloorModel floor,
    required RoomModel room,
    required List<StockItem> currentItems,
  });
  Future<void> updateInspectionChecklist({
    required String buildingId,
    required String floorId,
    required String roomId,
    required String inspectionId,
    required List<InspectionChecklistItem> checklistItems,
    required String overallNote,
  });
  Future<InspectionModel> syncInspectionChecklist({
    required String buildingId,
    required String floorId,
    required String roomId,
    required InspectionModel inspection,
  });
  Future<void> completeInspection({
    required BuildingModel building,
    required FloorModel floor,
    required RoomModel room,
    required InspectionModel inspection,
    required bool syncQuantities,
  });

  // ── Transfer ──
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
  });

  // ── Assignments ──
  Stream<List<ConsumableAssignment>> watchAssignments({
    String? itemId,
    String? roomId,
  });
  Stream<List<ConsumableAssignment>> watchAllAssignments();
  Future<void> assignConsumable({
    required BuildingModel building,
    required FloorModel floor,
    required RoomModel room,
    required StockItem item,
    required int quantity,
    required String assignedTo,
    required String note,
  });
  Future<void> returnConsumable({
    required BuildingModel building,
    required FloorModel floor,
    required RoomModel room,
    required StockItem item,
    required ConsumableAssignment assignment,
    required int returnQty,
  });
}
