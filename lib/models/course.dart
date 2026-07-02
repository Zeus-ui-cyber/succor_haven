// lib/models/course.dart
//
// Mirrors courses.controller.js browse()/getOne() response:
//   c.id, title, title_cn, category, age_group, difficulty, description,
//   thumbnail_url, features, pricing_id, pricing_name, credits_per_session,
//   session_type

class CourseModel {
  final String id;
  final String title;
  final String titleCn;
  final String category;
  final String? ageGroup;
  final String? difficulty;
  final String? description;
  final String? thumbnailUrl;
  final List<String> features;
  final String? pricingId;
  final String? pricingName;
  final int? creditsPerSession;
  final String? sessionType;

  const CourseModel({
    required this.id,
    required this.title,
    this.titleCn = '',
    required this.category,
    this.ageGroup,
    this.difficulty,
    this.description,
    this.thumbnailUrl,
    this.features = const [],
    this.pricingId,
    this.pricingName,
    this.creditsPerSession,
    this.sessionType,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) => CourseModel(
        id: json['id'].toString(),
        title: json['title'] as String? ?? '',
        titleCn: json['title_cn'] as String? ?? '',
        category: json['category'] as String? ?? '',
        ageGroup: json['age_group'] as String?,
        difficulty: json['difficulty'] as String?,
        description: json['description'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        features: (json['features'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        pricingId: json['pricing_id']?.toString(),
        pricingName: json['pricing_name'] as String?,
        creditsPerSession: (json['credits_per_session'] as num?)?.toInt(),
        sessionType: json['session_type'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'title_cn': titleCn,
        'category': category,
        'age_group': ageGroup,
        'difficulty': difficulty,
        'description': description,
        'thumbnail_url': thumbnailUrl,
        'features': features,
        'pricing_id': pricingId,
        'pricing_name': pricingName,
        'credits_per_session': creditsPerSession,
        'session_type': sessionType,
      };
}