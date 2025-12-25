import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/conversation.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Security exception for unauthorized access attempts
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

/// Conversation storage service using cloud API exclusively
///
/// All data is stored in PostgreSQL via the backend API.
class ConversationStorageService {
  final AuthService? _authService;
  bool _isInitialized = false;
  final Dio _dio = Dio();

  ConversationStorageService({AuthService? authService})
      : _authService = authService {
    _setupDio();
  }

  void _setupDio() {
    _dio.options.baseUrl = AppConfig.apiBaseUrl;
    _dio.options.connectTimeout = AppConfig.apiTimeout;
    _dio.options.receiveTimeout = AppConfig.apiTimeout;
  }

  /// Initialize the storage service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[ConversationStorage] Already initialized, skipping');
      return;
    }

    try {
      debugPrint(
          '[ConversationStorage] Initializing cloud storage (PostgreSQL)');
      _isInitialized = true;
      debugPrint('[ConversationStorage] Service initialized');
    } catch (e, stackTrace) {
      debugPrint('[ConversationStorage] Failed to initialize: $e');
      debugPrint('[ConversationStorage] Stack trace: $stackTrace');
      _isInitialized =
          true; // Still allow app to load, API calls will handle errors
    }
  }

  /// Save a list of conversations (Bulk update via individual API calls)
  Future<void> saveConversations(List<Conversation> conversations) async {
    for (final conversation in conversations) {
      await saveConversation(conversation);
    }
  }

  /// Load all conversations for current user from API
  Future<List<Conversation>> loadConversations() async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.get('/api/conversations',
          options: Options(headers: headers));

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final conversationsData = data['conversations'] as List<dynamic>? ?? [];

        final conversations = <Conversation>[];
        for (final convData in conversationsData) {
          // Note: The /api/conversations endpoint currently returns partial info
          // We could fetch full details if needed, but for the list view this might suffice
          // or we can adapt based on backend response

          // Reconstructing conversation from basic info
          conversations.add(Conversation.fromJson({
            'id': convData['id'],
            'title': convData['title'],
            'model': convData['model'],
            'createdAt': convData['created_at'],
            'updatedAt': convData['updated_at'],
            'metadata': convData['metadata'] ?? {},
            'messages':
                [], // Messages will be loaded when selecting a conversation
          }));
        }

        debugPrint(
          '[ConversationStorage] Loaded ${conversations.length} conversations from API',
        );
        return conversations;
      } else {
        debugPrint(
          '[ConversationStorage] Failed to load conversations: ${response.statusCode}',
        );
        return [];
      }
    } catch (e) {
      debugPrint(
          '[ConversationStorage] Error loading conversations from API: $e');
      return [];
    }
  }

  /// Fetch full conversation with messages
  Future<Conversation?> loadConversationWithMessages(
      String conversationId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.get('/api/conversations/$conversationId',
          options: Options(headers: headers));

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final convData = data['conversation'] as Map<String, dynamic>;

        return Conversation.fromJson({
          'id': convData['id'],
          'title': convData['title'],
          'model': convData['model'],
          'createdAt': convData['created_at'],
          'updatedAt': convData['updated_at'],
          'metadata': convData['metadata'] ?? {},
          'messages': (convData['messages'] as List<dynamic>?)
                  ?.map((m) => {
                        'id': m['id'],
                        'role': m['role'],
                        'content': m['content'],
                        'model': m['model'],
                        'timestamp': m['timestamp'],
                        'metadata': m['metadata'] ?? {},
                      })
                  .toList() ??
              [],
        });
      }
      return null;
    } catch (e) {
      debugPrint(
          '[ConversationStorage] Error loading conversation detail from API: $e');
      return null;
    }
  }

  /// Save a single conversation via API (update or insert)
  Future<void> saveConversation(Conversation conversation) async {
    try {
      final headers = await _getAuthHeaders();

      final body = {
        'title': conversation.title,
        'model': conversation.model,
        'metadata': conversation.metadata,
        'messages': conversation.messages
            .map((m) => {
                  'role': m.role.name,
                  'content': m.content,
                  'model': m.model,
                  'timestamp': m.timestamp.toIso8601String(),
                  'status': m.status.name,
                  'error': m.error,
                  'metadata': m.metadata,
                })
            .toList(),
      };

      final response = await _dio.put('/api/conversations/${conversation.id}',
          data: body, options: Options(headers: headers));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(
          '[ConversationStorage] Saved conversation via API: ${conversation.title}',
        );
      } else {
        throw Exception('Failed to save conversation: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ConversationStorage] Error saving conversation via API: $e');
      // Rethrow if authenticated, otherwise ignore to prevent crash on startup
      if (_authService?.isAuthenticated.value == true) {
        rethrow;
      }
    }
  }

  /// Delete a conversation via API
  Future<void> deleteConversation(String conversationId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.delete('/api/conversations/$conversationId',
          options: Options(headers: headers));

      if (response.statusCode == 200) {
        debugPrint(
            '[ConversationStorage] Deleted conversation via API: $conversationId');
      } else {
        throw Exception(
            'Failed to delete conversation: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(
          '[ConversationStorage] Error deleting conversation via API: $e');
      rethrow;
    }
  }

  /// Clear all conversations for current user
  Future<void> clearAllConversations() async {
    try {
      final conversations = await loadConversations();
      for (final conv in conversations) {
        await deleteConversation(conv.id);
      }
      debugPrint('[ConversationStorage] Cleared all conversations');
    } catch (e) {
      debugPrint('[ConversationStorage] Error clearing conversations: $e');
      rethrow;
    }
  }

  // ========== API Helper Methods ==========

  /// Get authentication headers for API requests
  Future<Map<String, String>> _getAuthHeaders() async {
    if (_authService == null) {
      throw StateError('AuthService not available');
    }

    final token = await _authService.getAccessToken();
    if (token == null) {
      throw SecurityException('No access token available');
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Check if the service is properly initialized
  bool get isInitialized => _isInitialized;

  /// Get database statistics (API-based)
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final conversations = await loadConversations();
    return {
      'total_conversations': conversations.length,
      'storage_type': 'PostgreSQL Cloud Storage',
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  /// Export all conversations for backup
  Future<Map<String, dynamic>> exportConversations() async {
    final conversations = await loadConversations();
    final fullConversations = <Map<String, dynamic>>[];

    for (final conv in conversations) {
      final fullConv = await loadConversationWithMessages(conv.id);
      if (fullConv != null) {
        fullConversations.add(fullConv.toJson());
      }
    }

    return {
      'conversations': fullConversations,
      'export_metadata': {
        'export_timestamp': DateTime.now().toIso8601String(),
        'total_conversations': fullConversations.length,
        'storage': 'PostgreSQL',
      },
    };
  }

  /// Set storage location preference (Stub for compatibility)
  Future<void> setStorageLocation(String location) async {
    debugPrint(
        '[ConversationStorage] setStorageLocation($location) called - no-op in cloud-only mode');
  }

  /// Set encryption enabled preference (Stub for compatibility)
  Future<void> setEncryptionEnabled(bool enabled) async {
    debugPrint(
        '[ConversationStorage] setEncryptionEnabled($enabled) called - no-op in cloud-only mode');
  }

  /// Close the service
  Future<void> dispose() async {
    _isInitialized = false;
    debugPrint('[ConversationStorage] Service disposed');
  }
}
