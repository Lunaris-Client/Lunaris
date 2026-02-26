import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';

class UploadResult {
  final String url;
  final String shortUrl;
  final String markdown;

  const UploadResult({
    required this.url,
    required this.shortUrl,
    required this.markdown,
  });
}

class UploadService {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;

  UploadService(this._apiClient, this._authService);

  Future<UploadResult?> pickAndUploadImage(
    String serverUrl, {
    ImageSource source = ImageSource.gallery,
  }) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 85);
    if (image == null) return null;
    return _upload(serverUrl, image.path, image.name);
  }

  Future<UploadResult?> pickAndUploadFile(String serverUrl) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.path == null) return null;
    return _upload(serverUrl, file.path!, file.name);
  }

  Future<UploadResult> _upload(
    String serverUrl,
    String filePath,
    String fileName,
  ) async {
    final apiKey = await _authService.loadApiKey(serverUrl);
    if (apiKey == null) throw Exception('Not authenticated');

    final data = await _apiClient.uploadFile(
      serverUrl,
      apiKey,
      filePath: filePath,
      fileName: fileName,
    );

    final url = data['url'] as String? ?? '';
    final shortUrl = data['short_url'] as String? ?? url;
    final originalFilename = data['original_filename'] as String? ?? fileName;
    final isImage = _isImageFile(fileName);

    final markdown =
        isImage
            ? '![$originalFilename|${data['width'] ?? ''}x${data['height'] ?? ''}]($shortUrl)'
            : '[$originalFilename|attachment]($shortUrl)';

    return UploadResult(url: url, shortUrl: shortUrl, markdown: markdown);
  }

  bool _isImageFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'heic', 'heif']
        .contains(ext);
  }

  void insertMarkdownAtCursor(TextEditingController controller, String md) {
    final sel = controller.selection;
    final text = controller.text;
    final offset = sel.isValid ? sel.start : text.length;

    final needsNewline = offset > 0 && text[offset - 1] != '\n';
    final insert = needsNewline ? '\n$md\n' : '$md\n';

    controller.text = text.replaceRange(offset, offset, insert);
    controller.selection = TextSelection.collapsed(
      offset: offset + insert.length,
    );
  }
}
