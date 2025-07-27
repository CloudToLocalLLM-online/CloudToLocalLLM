/// Model for prompt template metadata
library;

import '../services/langchain_prompt_service.dart';

/// Prompt template metadata model
class PromptTemplateModel {
  final String id;
  final String name;
  final String description;
  final PromptCategory category;
  final List<String> variables;
  final bool isBuiltIn;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PromptTemplateModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.variables,
    required this.isBuiltIn,
    this.createdAt,
    this.updatedAt,
  });

  /// Create a copy with updated fields
  PromptTemplateModel copyWith({
    String? id,
    String? name,
    String? description,
    PromptCategory? category,
    List<String>? variables,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromptTemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      variables: variables ?? this.variables,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.name,
      'variables': variables,
      'isBuiltIn': isBuiltIn,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory PromptTemplateModel.fromJson(Map<String, dynamic> json) {
    return PromptTemplateModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: PromptCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => PromptCategory.custom,
      ),
      variables: List<String>.from(json['variables'] as List),
      isBuiltIn: json['isBuiltIn'] as bool,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PromptTemplateModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PromptTemplateModel(id: $id, name: $name, category: ${category.name})';
  }
}
