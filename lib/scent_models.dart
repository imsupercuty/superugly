// lib/scent_models.dart

// API 응답을 저장할 Dart 모델
class ScentInfo {
  final String title;
  final String description;
  final String icon; // 화면 디자인을 위해 아이콘(이모지) 추가

  ScentInfo({required this.title, required this.description, required this.icon});

  factory ScentInfo.fromJson(Map<String, dynamic> json, String defaultIcon) {
    return ScentInfo(
      title: json['title'] as String,
      description: json['description'] as String,
      icon: defaultIcon, // 파싱 시 적절한 아이콘을 할당
    );
  }
}