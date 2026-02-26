import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_info.freezed.dart';
part 'server_info.g.dart';

@freezed
class ServerInfo with _$ServerInfo {
  const factory ServerInfo({
    required String url,
    required String siteName,
    String? logoUrl,
    String? description,
    String? faviconUrl,
    String? version,
  }) = _ServerInfo;

  factory ServerInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerInfoFromJson(json);
}
