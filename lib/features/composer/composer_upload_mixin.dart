import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lunaris/core/providers/providers.dart';

mixin ComposerUploadMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool isUploading = false;

  TextEditingController get uploadBodyController;
  String get uploadServerUrl;

  void showAttachPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                uploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                uploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Choose a file'),
              onTap: () {
                Navigator.pop(ctx);
                uploadFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> uploadImage(ImageSource source) async {
    setState(() => isUploading = true);
    try {
      final uploadService = ref.read(uploadServiceProvider);
      final result = await uploadService.pickAndUploadImage(
        uploadServerUrl,
        source: source,
      );
      if (result != null && mounted) {
        uploadService.insertMarkdownAtCursor(
            uploadBodyController, result.markdown);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> uploadFile() async {
    setState(() => isUploading = true);
    try {
      final uploadService = ref.read(uploadServiceProvider);
      final result =
          await uploadService.pickAndUploadFile(uploadServerUrl);
      if (result != null && mounted) {
        uploadService.insertMarkdownAtCursor(
            uploadBodyController, result.markdown);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }
}
