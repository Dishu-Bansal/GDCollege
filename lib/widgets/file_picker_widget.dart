import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
// Alias to avoid conflict with package name
import 'package:file_picker/file_picker.dart' as file_picker;

class FilePicker extends StatelessWidget {
  final String label;
  final Uint8List? filePath;
  final String? filename;
  final void Function(Uint8List data, String name) onFilePicked;
  final void Function() onFileRemoved;
  final bool imageOnly;
  final bool isRequired;

  const FilePicker({
    super.key,
    required this.label,
    required this.filePath,
    required this.filename,
    required this.onFilePicked,
    required this.onFileRemoved,
    this.imageOnly = false,
    this.isRequired = false,
  });

  Future<void> _pickFile(BuildContext context) async {
    if (imageOnly) {
      final picker = ImagePicker();
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
            ],
          ),
        ),
      );
      if (action == null) return;
      final XFile? img = action == 'camera'
          ? await picker.pickImage(source: ImageSource.camera, imageQuality: 80)
          : await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (img != null) onFilePicked((await img.readAsBytes()), img.name);
    } else {
      final result = await file_picker.FilePicker.platform.pickFiles(
        type: file_picker.FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
      if (result != null && result.files.single.bytes != null) {
        final bytes = await result.files.single.size;
        if (bytes > 1 * 1024 * 1024) {
          if (context.mounted) {
            _showSizeError(context, 'Photo must be under 5 MB');
          }
          return;
        }
        onFilePicked(result.files.single.bytes!, result.files.single.name!);
      }
    }
  }

  void _showSizeError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = filePath != null && filePath!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRequired ? '$label *' : label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: hasFile ? null : () => _pickFile(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasFile
                    ? const Color(0xFF1A3C6E).withOpacity(0.05)
                    : Colors.grey.shade50,
                border: Border.all(
                  color: hasFile
                      ? const Color(0xFF1A3C6E).withOpacity(0.4)
                      : Colors.grey.shade300,
                  width: hasFile ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // Preview if image
                  if (hasFile && imageOnly)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        filePath!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: hasFile
                            ? const Color(0xFF1A3C6E).withOpacity(0.15)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasFile
                            ? (imageOnly ? Icons.image : Icons.description)
                            : Icons.upload_file,
                        color: hasFile
                            ? const Color(0xFF1A3C6E)
                            : Colors.grey,
                        size: 22,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasFile
                              ? this.filename!
                              : 'Tap to select file',
                          style: TextStyle(
                            fontWeight: hasFile
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: hasFile
                                ? const Color(0xFF1A3C6E)
                                : Colors.grey,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!hasFile)
                          Text(
                            imageOnly
                                ? 'JPG, PNG supported'
                                : 'PDF, JPG, PNG, DOC supported',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
                          ),
                      ],
                    ),
                  ),
                  if (hasFile)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.redAccent,
                      onPressed: onFileRemoved,
                    )
                  else
                    const Icon(Icons.arrow_forward_ios,
                        size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// Multi-file picker for "FILES" field
class MultiFilePicker extends StatelessWidget {
  final String label;
  final List<String> filePaths;
  BuildContext? mycontext;
  final void Function(Uint8List data, String name) onFileAdded;
  final void Function(int index) onFileRemoved;

  MultiFilePicker({
    super.key,
    required this.label,
    required this.filePaths,
    required this.onFileAdded,
    required this.onFileRemoved,
  });

  void _showSizeError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await file_picker.FilePicker.platform.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (result != null && result.files.single.bytes != null) {
      final sizeBytes = result.files.single.size;
      if (sizeBytes > 1 * 1024 * 1024) {
        _showSizeError(mycontext!, 'File must be under 5 MB');
        return;
      }
      onFileAdded(result.files.single.bytes!, result.files.single.name!);
    }
  }

  @override
  Widget build(BuildContext context) {
    mycontext = context;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          ...List.generate(filePaths.length, (i) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3C6E).withOpacity(0.05),
                border: Border.all(
                    color: const Color(0xFF1A3C6E).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description,
                      color: Color(0xFF1A3C6E), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.basename(filePaths[i]),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1A3C6E)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.redAccent),
                    onPressed: () => onFileRemoved(i),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add File'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A3C6E),
              side: const BorderSide(color: Color(0xFF1A3C6E)),
            ),
          ),
        ],
      ),
    );
  }
}
