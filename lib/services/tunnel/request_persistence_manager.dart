/// Request Persistence Manager
/// Handles persistence of high-priority requests to disk
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'persistent_request_queue.dart';

/// Request persistence manager
/// Handles saving and restoring high-priority requests
class RequestPersistenceManager {
  final String persistenceKey;
  final int maxPersistedRequests;

  RequestPersistenceManager({
    this.persistenceKey = 'tunnel_queued_requests',
    this.maxPersistedRequests = 50,
  });

  /// Persist a single request
  Future<bool> persistRequest(QueuedRequest queuedRequest) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getPersistedRequests(prefs);

      // Check if we've reached the limit
      if (existing.length >= maxPersistedRequests) {
        // Remove oldest request (first in list)
        existing.removeAt(0);
      }

      // Add new request
      existing.add(queuedRequest.toJson());

      // Save back to preferences
      await prefs.setString(persistenceKey, jsonEncode(existing));
      return true;
    } catch (e) {
      debugPrint('Failed to persist request ${queuedRequest.request.id}: $e');
      return false;
    }
  }

  /// Persist multiple requests
  Future<int> persistRequests(List<QueuedRequest> requests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getPersistedRequests(prefs);

      int persisted = 0;
      for (final request in requests) {
        if (existing.length >= maxPersistedRequests) {
          break; // Stop if we've reached the limit
        }
        existing.add(request.toJson());
        persisted++;
      }

      await prefs.setString(persistenceKey, jsonEncode(existing));
      return persisted;
    } catch (e) {
      debugPrint('Failed to persist requests: $e');
      return 0;
    }
  }

  /// Remove a persisted request by ID
  Future<bool> removePersistedRequest(String requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _getPersistedRequests(prefs);

      // Filter out the request with matching ID
      final filtered = existing.where((json) {
        try {
          final request = json['request'] as Map<String, dynamic>;
          return request['id'] != requestId;
        } catch (e) {
          // Keep malformed entries for manual cleanup
          return true;
        }
      }).toList();

      if (filtered.length != existing.length) {
        await prefs.setString(persistenceKey, jsonEncode(filtered));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to remove persisted request $requestId: $e');
      return false;
    }
  }

  /// Restore persisted requests
  Future<List<QueuedRequest>> restorePersistedRequests({
    bool clearAfterRestore = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = await _getPersistedRequests(prefs);
      final restored = <QueuedRequest>[];

      for (final json in persisted) {
        try {
          final queuedRequest = QueuedRequest.fromJson(json);

          // Only restore if not timed out
          if (!queuedRequest.isTimedOut) {
            restored.add(queuedRequest);
          }
        } catch (e) {
          debugPrint('Skipping corrupted persisted request: $e');
        }
      }

      // Clear persistence after restoration if requested
      if (clearAfterRestore) {
        await clearPersistedRequests();
      }

      return restored;
    } catch (e) {
      debugPrint('Failed to restore persisted requests: $e');
      return [];
    }
  }

  /// Clear all persisted requests
  Future<bool> clearPersistedRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(persistenceKey);
      return true;
    } catch (e) {
      debugPrint('Failed to clear persisted requests: $e');
      return false;
    }
  }

  /// Get count of persisted requests
  Future<int> getPersistedCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = await _getPersistedRequests(prefs);
      return persisted.length;
    } catch (e) {
      debugPrint('Failed to get persisted count: $e');
      return 0;
    }
  }

  /// Check if persistence storage is corrupted
  Future<bool> isCorrupted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _getPersistedRequests(prefs);
      return false;
    } catch (e) {
      return true;
    }
  }

  /// Repair corrupted persistence storage
  Future<bool> repairCorrupted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(persistenceKey);

      if (jsonStr == null) {
        return true; // Nothing to repair
      }

      // Try to parse and filter out corrupted entries
      final List<dynamic> rawList = jsonDecode(jsonStr) as List<dynamic>;
      final validRequests = <Map<String, dynamic>>[];

      for (final item in rawList) {
        try {
          final json = item as Map<String, dynamic>;
          // Try to parse as QueuedRequest to validate
          QueuedRequest.fromJson(json);
          validRequests.add(json);
        } catch (e) {
          // Skip corrupted entry
          debugPrint('Removing corrupted entry during repair: $e');
        }
      }

      // Save repaired data
      await prefs.setString(persistenceKey, jsonEncode(validRequests));
      return true;
    } catch (e) {
      debugPrint('Failed to repair corrupted persistence: $e');
      // If repair fails, clear everything
      await clearPersistedRequests();
      return false;
    }
  }

  /// Get persisted requests from SharedPreferences
  Future<List<Map<String, dynamic>>> _getPersistedRequests(
    SharedPreferences prefs,
  ) async {
    final jsonStr = prefs.getString(persistenceKey);
    if (jsonStr == null) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Failed to decode persisted requests: $e');
      throw FormatException('Corrupted persistence data');
    }
  }

  /// Get statistics about persisted requests
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = await _getPersistedRequests(prefs);

      final priorityCounts = <String, int>{
        'high': 0,
        'normal': 0,
        'low': 0,
      };

      int timedOut = 0;

      for (final json in persisted) {
        try {
          final queuedRequest = QueuedRequest.fromJson(json);
          priorityCounts[queuedRequest.priority.name] =
              (priorityCounts[queuedRequest.priority.name] ?? 0) + 1;

          if (queuedRequest.isTimedOut) {
            timedOut++;
          }
        } catch (e) {
          // Skip corrupted entries
        }
      }

      return {
        'total': persisted.length,
        'maxAllowed': maxPersistedRequests,
        'priorityCounts': priorityCounts,
        'timedOut': timedOut,
        'isCorrupted': false,
      };
    } catch (e) {
      return {
        'total': 0,
        'maxAllowed': maxPersistedRequests,
        'priorityCounts': {'high': 0, 'normal': 0, 'low': 0},
        'timedOut': 0,
        'isCorrupted': true,
      };
    }
  }
}
