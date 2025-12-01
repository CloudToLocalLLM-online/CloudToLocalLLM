import 'user_model.dart';

/// Model representing an authentication session stored in PostgreSQL
class SessionModel {
  final String id;
  final String userId;
  final String token;
  final DateTime expiresAt;
  final UserModel user;
  final DateTime createdAt;
  final DateTime lastActivity;
  final bool isActive;

  SessionModel({
    required this.id,
    required this.userId,
    required this.token,
    required this.expiresAt,
    required this.user,
    DateTime? createdAt,
    DateTime? lastActivity,
    this.isActive = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActivity = lastActivity ?? DateTime.now();

  /// Check if the session is still valid (not expired and active)
  bool get isValid {
    return isActive && expiresAt.isAfter(DateTime.now());
  }

  /// Create a copy with updated fields
  SessionModel copyWith({
    String? id,
    String? userId,
    String? token,
    DateTime? expiresAt,
    UserModel? user,
    DateTime? createdAt,
    DateTime? lastActivity,
    bool? isActive,
  }) {
    return SessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      expiresAt: expiresAt ?? this.expiresAt,
      user: user ?? this.user,
      createdAt: createdAt ?? this.createdAt,
      lastActivity: lastActivity ?? this.lastActivity,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'SessionModel(id: $id, userId: $userId, token: ${token.substring(0, 8)}..., expiresAt: $expiresAt, isValid: $isValid)';
  }
}
