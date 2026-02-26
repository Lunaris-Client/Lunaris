import 'package:freezed_annotation/freezed_annotation.dart';

part 'site_category.freezed.dart';
part 'site_category.g.dart';

@freezed
class SiteCategory with _$SiteCategory {
  const factory SiteCategory({
    required int id,
    required String name,
    required String slug,
    required String color,
    @Default('FFFFFF') String textColor,
    int? position,
    String? descriptionExcerpt,
    int? parentCategoryId,
    @Default(0) int topicCount,
    @Default(0) int postCount,
    @Default(false) bool hasChildren,
    @Default(0) int subcategoryCount,
    @Default(false) bool readRestricted,
    int? notificationLevel,
    String? uploadedLogoUrl,
    String? uploadedLogoDarkUrl,
    String? emoji,
    String? icon,
    String? defaultView,
    String? sortOrder,
    bool? sortAscending,
  }) = _SiteCategory;

  factory SiteCategory.fromJson(Map<String, dynamic> json) =>
      _$SiteCategoryFromJson(json);

  factory SiteCategory.fromSiteJson(Map<String, dynamic> json) {
    return SiteCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      color: json['color'] as String? ?? '0088CC',
      textColor: json['text_color'] as String? ?? 'FFFFFF',
      position: json['position'] as int?,
      descriptionExcerpt: json['description_excerpt'] as String?,
      parentCategoryId: json['parent_category_id'] as int?,
      topicCount: json['topic_count'] as int? ?? 0,
      postCount: json['post_count'] as int? ?? 0,
      hasChildren: json['has_children'] as bool? ?? false,
      subcategoryCount: json['subcategory_count'] as int? ?? 0,
      readRestricted: json['read_restricted'] as bool? ?? false,
      notificationLevel: json['notification_level'] as int?,
      uploadedLogoUrl: _extractUploadUrl(json['uploaded_logo']),
      uploadedLogoDarkUrl: _extractUploadUrl(json['uploaded_logo_dark']),
      emoji: json['emoji'] as String?,
      icon: json['icon'] as String?,
      defaultView: json['default_view'] as String?,
      sortOrder: json['sort_order'] as String?,
      sortAscending: json['sort_ascending'] as bool?,
    );
  }

  static String? _extractUploadUrl(dynamic upload) {
    if (upload is Map<String, dynamic>) return upload['url'] as String?;
    return null;
  }
}
