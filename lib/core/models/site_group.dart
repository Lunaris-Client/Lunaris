import 'package:freezed_annotation/freezed_annotation.dart';

part 'site_group.freezed.dart';
part 'site_group.g.dart';

@freezed
class SiteGroup with _$SiteGroup {
  const factory SiteGroup({
    required int id,
    required String name,
    String? flairUrl,
    String? flairBgColor,
    String? flairColor,
    @Default(false) bool automatic,
  }) = _SiteGroup;

  factory SiteGroup.fromJson(Map<String, dynamic> json) =>
      _$SiteGroupFromJson(json);

  factory SiteGroup.fromSiteJson(Map<String, dynamic> json) {
    return SiteGroup(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      flairUrl: json['flair_url'] as String?,
      flairBgColor: json['flair_bg_color'] as String?,
      flairColor: json['flair_color'] as String?,
      automatic: json['automatic'] as bool? ?? false,
    );
  }
}
