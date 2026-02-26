import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/models/site_group.dart';

part 'site_data.freezed.dart';
part 'site_data.g.dart';

@freezed
class SiteData with _$SiteData {
  const factory SiteData({
    required List<SiteCategory> categories,
    required List<SiteGroup> groups,
    required Map<String, int> notificationTypes,
    required List<String> filters,
    required List<String> periods,
    required List<String> topMenuItems,
    required Map<String, int> trustLevels,
    required Map<String, int> postTypes,
    required List<PostActionType> postActionTypes,
    @Default([]) List<String> topTags,
    @Default(false) bool canCreateTag,
    @Default(false) bool canTagTopics,
    int? uncategorizedCategoryId,
    required DateTime fetchedAt,
  }) = _SiteData;

  factory SiteData.fromJson(Map<String, dynamic> json) =>
      _$SiteDataFromJson(json);

  factory SiteData.fromSiteJson(Map<String, dynamic> json) {
    final categories = (json['categories'] as List<dynamic>?)
            ?.map((c) =>
                SiteCategory.fromSiteJson(c as Map<String, dynamic>))
            .toList() ??
        [];

    final groups = (json['groups'] as List<dynamic>?)
            ?.map(
                (g) => SiteGroup.fromSiteJson(g as Map<String, dynamic>))
            .toList() ??
        [];

    final notificationTypes =
        _parseIntMap(json['notification_types']);
    final trustLevels = _parseIntMap(json['trust_levels']);
    final postTypes = _parseIntMap(json['post_types']);

    final filters = (json['filters'] as List<dynamic>?)
            ?.map((f) => f.toString())
            .toList() ??
        [];

    final periods = (json['periods'] as List<dynamic>?)
            ?.map((p) => p.toString())
            .toList() ??
        [];

    final topMenuItems = (json['top_menu_items'] as List<dynamic>?)
            ?.map((t) => t.toString())
            .toList() ??
        [];

    final postActionTypes = (json['post_action_types'] as List<dynamic>?)
            ?.map((a) =>
                PostActionType.fromSiteJson(a as Map<String, dynamic>))
            .toList() ??
        [];

    final topTags = (json['top_tags'] as List<dynamic>?)
            ?.map((t) {
              if (t is Map<String, dynamic>) return t['name']?.toString() ?? '';
              return t.toString();
            })
            .where((t) => t.isNotEmpty)
            .toList() ??
        [];

    return SiteData(
      categories: categories,
      groups: groups,
      notificationTypes: notificationTypes,
      filters: filters,
      periods: periods,
      topMenuItems: topMenuItems,
      trustLevels: trustLevels,
      postTypes: postTypes,
      postActionTypes: postActionTypes,
      topTags: topTags,
      canCreateTag: json['can_create_tag'] as bool? ?? false,
      canTagTopics: json['can_tag_topics'] as bool? ?? false,
      uncategorizedCategoryId: json['uncategorized_category_id'] as int?,
      fetchedAt: DateTime.now(),
    );
  }

  static Map<String, int> _parseIntMap(dynamic value) {
    if (value is! Map) return {};
    return value.map((k, v) => MapEntry(k.toString(), v is int ? v : 0));
  }
}

@freezed
class PostActionType with _$PostActionType {
  const factory PostActionType({
    required int id,
    required String nameKey,
    String? name,
    String? description,
    @Default(false) bool isFlag,
    String? icon,
  }) = _PostActionType;

  factory PostActionType.fromJson(Map<String, dynamic> json) =>
      _$PostActionTypeFromJson(json);

  factory PostActionType.fromSiteJson(Map<String, dynamic> json) {
    return PostActionType(
      id: json['id'] as int,
      nameKey: json['name_key'] as String? ?? '',
      name: json['name'] as String?,
      description: json['description'] as String?,
      isFlag: json['is_flag'] as bool? ?? false,
      icon: json['icon'] as String?,
    );
  }
}
