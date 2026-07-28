import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/stock_models.dart';
import '../../repositories/stock_repository.dart';
import '../../providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/stock_widgets.dart';
import 'room_detail_screen.dart';

class RoomsScreen extends ConsumerWidget {
  final BuildingModel building;
  final FloorModel floor;

  const RoomsScreen(
      {super.key, required this.building, required this.floor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(stockRepositoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(floor.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${building.name}  â€º  Rooms',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70)),
            ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Room',
            onPressed: () => _addRoom(context, service),
          ),
        ],
      ),
      body: StreamBuilder<List<RoomModel>>(
        stream: service.watchRooms(building.id!, floor.id!),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rooms = snap.data ?? [];
          if (rooms.isEmpty) {
            return StockEmptyState(
              message:
              'No rooms on ${floor.name}.\nAdd a room to start tracking stock.',
              actionLabel: 'Add Room',
              onAction: () => _addRoom(context, service),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            itemBuilder: (_, i) => _RoomCard(
              room: rooms[i],
              building: building,
              floor: floor,
              service: service,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRoom(context, service),
        backgroundColor: const Color(0xFF1A3C6E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Room',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _addRoom(
      BuildContext context, StockRepository service) async {
    final name = await showNameDialog(context,
        title: 'Add Room',
        hint: 'e.g. Room 101, Lab A, Store Room');
    if (name != null) {
      await service.addRoom(building.id!, floor.id!, name);
    }
  }
}

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  final BuildingModel building;
  final FloorModel floor;
  final StockRepository service;

  const _RoomCard({
    required this.room,
    required this.building,
    required this.floor,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final photoCount = room.photoUrls.length;
    final videoCount = room.videoUrls.length;
    // Feature: Media Freshness
    final overdue = room.isMediaOverdue;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoomDetailScreen(
              building: building,
              floor: floor,
              room: room,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.meeting_room_outlined,
                      color: Colors.orange, size: 26),
                ),
                // Feature: Media Freshness badge
                if (overdue)
                  const Positioned(
                    top: -4,
                    right: -4,
                    child: MediaOverdueBadge(),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (photoCount > 0) ...[
                      Icon(Icons.photo_outlined,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text('$photoCount',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                      const SizedBox(width: 10),
                    ],
                    if (videoCount > 0) ...[
                      Icon(Icons.videocam_outlined,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text('$videoCount',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                    ],
                    if (photoCount == 0 && videoCount == 0)
                      Text('No media uploaded',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400)),
                  ]),
                  // Feature: Media Freshness â€” show overdue label
                  if (overdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        room.lastMediaUploadedAt == null
                            ? 'No media ever uploaded'
                            : 'Media overdue (>30 days)',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
            // Quick media upload button
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined,
                  color: Color(0xFF1A3C6E), size: 20),
              tooltip: 'Upload media',
              onPressed: () => _showMediaOptions(context, service),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final name = await showNameDialog(context,
                      title: 'Rename Room', initial: room.name);
                  if (name != null) {
                    await service.updateRoom(
                        building.id!, floor.id!, room.id!, name);
                  }
                } else if (v == 'delete') {
                  final ok = await confirmDelete(context,
                      label: room.name);
                  if (ok) {
                    await service.deleteRoom(
                        building.id!, floor.id!, room.id!);
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'rename',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Rename'),
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ])),
              ],
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Future<void> _showMediaOptions(
      BuildContext context, StockRepository service) async {
    await showModalBottomSheet(
      context: context,
      // useRootNavigator keeps the sheet alive when the gallery/camera
      // pushes its own platform route on top.
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => MediaUploadSheet(
        building: building,
        floor: floor,
        room: room,
        service: service,
      ),
    );
  }
}

// â”€â”€ Media upload bottom sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class MediaUploadSheet extends StatefulWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel room;
  final StockRepository service;

  MediaUploadSheet({
    required this.building,
    required this.floor,
    required this.room,
    required this.service,
  });

  @override
  State<MediaUploadSheet> createState() => _MediaUploadSheetState();
}

class _MediaUploadSheetState extends State<MediaUploadSheet> {
  bool _uploading = false;
  String _status = '';
  double _progress = 0;

  Future<void> _pickAndUpload(
      {required bool isVideo, required ImageSource source}) async {
    final picker = ImagePicker();
    XFile? file;

    // Pick the file BEFORE touching any state. The gallery/camera pushes its
    // own platform route; on Android this can dismiss the bottom sheet context.
    if (isVideo) {
      file = await picker.pickVideo(source: source);
    } else {
      file = await picker.pickImage(source: source, imageQuality: 80);
    }

    // User cancelled
    if (file == null) return;

    // Sheet may have been dismissed while the gallery was open
    if (!mounted) return;

    setState(() {
      _uploading = true;
      _status = 'Uploadingâ€¦';
      _progress = 0;
    });

    try {
      final url = await widget.service.uploadRoomMedia(
        xfile: file,
        buildingId: widget.building.id!,
        floorId: widget.floor.id!,
        roomId: widget.room.id!,
        isVideo: isVideo,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _progress = p;
              _status = '${(p * 100).toStringAsFixed(0)}%';
            });
          }
        },
      );

      if (!mounted) return;

      if (url != null) {
        if (isVideo) {
          await widget.service.addRoomVideo(widget.building.id!,
              widget.floor.id!, widget.room.id!, url);
        } else {
          await widget.service.addRoomPhoto(widget.building.id!,
              widget.floor.id!, widget.room.id!, url);
        }
      }

      if (!mounted) return;

      setState(() {
        _uploading = false;
        _status = 'Done!';
      });

      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _status = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _uploading
          ? Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(
              Color(0xFF1A3C6E)),
        ),
        const SizedBox(height: 12),
        Text(_status,
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 8),
      ])
          : Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Text('Upload Media',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF1A3C6E))),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context)),
        ]),
        const SizedBox(height: 8),
        Text('Room: ${widget.room.name}',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 20),
        _MediaOption(
          icon: Icons.camera_alt_outlined,
          label: 'Take Photo',
          onTap: () => _pickAndUpload(
              isVideo: false, source: ImageSource.camera),
        ),
        _MediaOption(
          icon: Icons.photo_library_outlined,
          label: 'Photo from Gallery',
          onTap: () => _pickAndUpload(
              isVideo: false, source: ImageSource.gallery),
        ),
        _MediaOption(
          icon: Icons.videocam_outlined,
          label: 'Record Video',
          onTap: () => _pickAndUpload(
              isVideo: true, source: ImageSource.camera),
        ),
        _MediaOption(
          icon: Icons.video_library_outlined,
          label: 'Video from Gallery',
          onTap: () => _pickAndUpload(
              isVideo: true, source: ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _MediaOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3C6E).withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child:
        Icon(icon, color: const Color(0xFF1A3C6E), size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
    );
  }
}
