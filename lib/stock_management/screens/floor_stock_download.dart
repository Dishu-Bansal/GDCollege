import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import '../../repositories/stock_repository.dart';
import '../models/stock_models.dart';

/// Downloads a floor's stock as .xlsx: one sheet per room with item names
/// and quantities. Called from the floor card menu.
Future<void> downloadFloorStock({
  required BuildContext context,
  required StockRepository service,
  required BuildingModel building,
  required FloorModel floor,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void note(String msg) =>
      messenger.showSnackBar(SnackBar(content: Text(msg)));

  try {
    final roomsFuture =
        service.watchRooms(building.id!, floor.id!).first;
    final itemsFuture = service.watchAllRoomItems().first;
    final rooms = await roomsFuture;
    final all = await itemsFuture;

    // Room-scoped rows (this floor only), grouped by room.
    final byRoom = <String, List<ScopedStockItem>>{};
    for (final s in all) {
      if (s.buildingId != building.id || s.floorId != floor.id) continue;
      (byRoom[s.roomId] ??= []).add(s);
    }
    for (final rows in byRoom.values) {
      rows.sort((a, b) => a.item.name.compareTo(b.item.name));
    }

    final excel = Excel.createExcel();
    var first = true;
    final usedSheets = <String>{};
    // Every room gets a sheet, even an empty one.
    final orderedRooms = [...rooms]
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final room in orderedRooms) {
      final sheetName = _uniqueSheet(
          _sanitizeSheet(room.name.isEmpty ? 'Room' : room.name),
          usedSheets);
      final Sheet sheet;
      if (first) {
        excel.rename('Sheet1', sheetName);
        sheet = excel[sheetName];
        first = false;
      } else {
        sheet = excel[sheetName];
      }
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = TextCellValue('Item Name');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
          .value = TextCellValue('Quantity');
      final rows = byRoom[room.id] ?? [];
      for (var r = 0; r < rows.length; r++) {
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: r + 1))
            .value = TextCellValue(rows[r].item.name);
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: 1, rowIndex: r + 1))
            .value =
            IntCellValue(rows[r].item.currentQuantity);
      }
      usedSheets.add(sheetName);
    }
    if (first) {
      // No rooms on the floor: keep a single sheet explaining that.
      excel.rename('Sheet1', 'Rooms');
      excel['Rooms']
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = TextCellValue('No rooms on this floor');
    }
    final filename =
        'stock_${_slug(building.name)}_${_slug(floor.name)}.xlsx';
    // save() triggers the single browser download on web.
    if (excel.save(fileName: filename) == null) {
      throw StateError('Excel encoding failed');
    }
    note('Downloaded ${orderedRooms.length} room sheet(s)');
  } catch (e) {
    note('Download failed: $e');
  }
}

/// Excel sheet names: max 31 chars, none of / \ ? * [ ] :.
String _sanitizeSheet(String name) {
  var clean = name.replaceAll(RegExp(r'[/\\?*\[\]:]'), ' ').trim();
  if (clean.isEmpty) clean = 'Room';
  return clean.length > 31 ? clean.substring(0, 31).trim() : clean;
}

String _uniqueSheet(String base, Set<String> used) {
  var name = base;
  var i = 2;
  while (used.contains(name)) {
    final suffix = ' ($i)';
    final stem = base.length + suffix.length > 31
        ? base.substring(0, 31 - suffix.length).trim()
        : base;
    name = '$stem$suffix';
    i++;
  }
  return name;
}

String _slug(String s) {
  final clean =
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final trimmed = clean.replaceAll(RegExp(r'^-+|-+$'), '');
  return trimmed.isEmpty ? 'unnamed' : trimmed;
}
