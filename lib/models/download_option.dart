/// Model representing a download option for a specific platform
class DownloadOption {
  final String name;
  final String description;
  final String downloadUrl;
  final String fileSize;
  final String installationType; // 'msi', 'zip', 'appimage', 'deb', 'dmg'
  final String? iconPath;
  final bool isRecommended;
  final List<String> requirements;

  const DownloadOption({
    required this.name,
    required this.description,
    required this.downloadUrl,
    required this.fileSize,
    required this.installationType,
    this.iconPath,
    this.isRecommended = false,
    this.requirements = const [],
  });

  /// Create a copy of this download option with updated fields
  DownloadOption copyWith({
    String? name,
    String? description,
    String? downloadUrl,
    String? fileSize,
    String? installationType,
    String? iconPath,
    bool? isRecommended,
    List<String>? requirements,
  }) {
    return DownloadOption(
      name: name ?? this.name,
      description: description ?? this.description,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSize: fileSize ?? this.fileSize,
      installationType: installationType ?? this.installationType,
      iconPath: iconPath ?? this.iconPath,
      isRecommended: isRecommended ?? this.isRecommended,
      requirements: requirements ?? this.requirements,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'downloadUrl': downloadUrl,
      'fileSize': fileSize,
      'installationType': installationType,
      'iconPath': iconPath,
      'isRecommended': isRecommended,
      'requirements': requirements,
    };
  }

  /// Create from JSON
  factory DownloadOption.fromJson(Map<String, dynamic> json) {
    return DownloadOption(
      name: json['name'] as String,
      description: json['description'] as String,
      downloadUrl: json['downloadUrl'] as String,
      fileSize: json['fileSize'] as String,
      installationType: json['installationType'] as String,
      iconPath: json['iconPath'] as String?,
      isRecommended: json['isRecommended'] as bool? ?? false,
      requirements: (json['requirements'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  @override
  String toString() {
    return 'DownloadOption(name: $name, installationType: $installationType, isRecommended: $isRecommended)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DownloadOption &&
        other.name == name &&
        other.installationType == installationType &&
        other.downloadUrl == downloadUrl;
  }

  @override
  int get hashCode {
    return Object.hash(name, installationType, downloadUrl);
  }
}
