/// Model representing a single installation step with visual aids and commands
class InstallationStep {
  final String title;
  final String description;
  final String? imageUrl;
  final List<String> commands;
  final List<String> troubleshootingTips;
  final List<String>
      applicableTypes; // Which installation types this step applies to
  final int order;
  final bool isOptional;

  const InstallationStep({
    required this.title,
    required this.description,
    this.imageUrl,
    this.commands = const [],
    this.troubleshootingTips = const [],
    this.applicableTypes = const [],
    this.order = 0,
    this.isOptional = false,
  });

  /// Create a copy of this installation step with updated fields
  InstallationStep copyWith({
    String? title,
    String? description,
    String? imageUrl,
    List<String>? commands,
    List<String>? troubleshootingTips,
    List<String>? applicableTypes,
    int? order,
    bool? isOptional,
  }) {
    return InstallationStep(
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      commands: commands ?? this.commands,
      troubleshootingTips: troubleshootingTips ?? this.troubleshootingTips,
      applicableTypes: applicableTypes ?? this.applicableTypes,
      order: order ?? this.order,
      isOptional: isOptional ?? this.isOptional,
    );
  }

  /// Check if this step applies to a specific installation type
  bool appliesTo(String installationType) {
    return applicableTypes.isEmpty ||
        applicableTypes.contains(installationType.toLowerCase());
  }

  /// Get formatted commands as a single string
  String get formattedCommands {
    return commands.join('\n');
  }

  /// Get formatted troubleshooting tips as a single string
  String get formattedTroubleshooting {
    return troubleshootingTips.map((tip) => '• $tip').join('\n');
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'commands': commands,
      'troubleshootingTips': troubleshootingTips,
      'applicableTypes': applicableTypes,
      'order': order,
      'isOptional': isOptional,
    };
  }

  /// Create from JSON
  factory InstallationStep.fromJson(Map<String, dynamic> json) {
    return InstallationStep(
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      commands: (json['commands'] as List<dynamic>?)
              ?.map((c) => c as String)
              .toList() ??
          [],
      troubleshootingTips: (json['troubleshootingTips'] as List<dynamic>?)
              ?.map((t) => t as String)
              .toList() ??
          [],
      applicableTypes: (json['applicableTypes'] as List<dynamic>?)
              ?.map((t) => t as String)
              .toList() ??
          [],
      order: json['order'] as int? ?? 0,
      isOptional: json['isOptional'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'InstallationStep(title: $title, order: $order, applicableTypes: $applicableTypes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InstallationStep &&
        other.title == title &&
        other.order == order &&
        other.applicableTypes.toString() == applicableTypes.toString();
  }

  @override
  int get hashCode {
    return Object.hash(title, order, applicableTypes.toString());
  }
}
