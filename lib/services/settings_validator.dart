/// Settings Validator
///
/// Provides validation logic for all setting types with detailed error messages.
library;

/// Validation result containing success status and error messages
class ValidationResult {
  /// Whether validation passed
  final bool isValid;

  /// Map of field names to error messages
  final Map<String, String> errors;

  /// Overall error message (if any)
  final String? overallError;

  const ValidationResult({
    required this.isValid,
    this.errors = const {},
    this.overallError,
  });

  /// Create a successful validation result
  factory ValidationResult.success() {
    return const ValidationResult(isValid: true);
  }

  /// Create a failed validation result with field errors
  factory ValidationResult.fieldErrors(Map<String, String> errors) {
    return ValidationResult(
      isValid: false,
      errors: errors,
    );
  }

  /// Create a failed validation result with an overall error
  factory ValidationResult.error(String message) {
    return ValidationResult(
      isValid: false,
      overallError: message,
    );
  }

  /// Get all error messages as a list
  List<String> getAllErrors() {
    final allErrors = <String>[];
    if (overallError != null) {
      allErrors.add(overallError!);
    }
    allErrors.addAll(errors.values);
    return allErrors;
  }
}

/// Settings Validator for validating all setting types
class SettingsValidator {
  /// Validate theme setting
  static ValidationResult validateTheme(String? theme) {
    if (theme == null || theme.isEmpty) {
      return ValidationResult.fieldErrors({
        'theme': 'Theme is required',
      });
    }

    const validThemes = ['light', 'dark', 'system'];
    if (!validThemes.contains(theme)) {
      return ValidationResult.fieldErrors({
        'theme': 'Invalid theme. Must be light, dark, or system',
      });
    }

    return ValidationResult.success();
  }

  /// Validate language setting
  static ValidationResult validateLanguage(String? language) {
    if (language == null || language.isEmpty) {
      return ValidationResult.fieldErrors({
        'language': 'Language is required',
      });
    }

    const validLanguages = ['en', 'es', 'fr', 'de', 'ja', 'zh'];
    if (!validLanguages.contains(language)) {
      return ValidationResult.fieldErrors({
        'language': 'Invalid language. Must be one of: en, es, fr, de, ja, zh',
      });
    }

    return ValidationResult.success();
  }

  /// Validate provider host URL
  static ValidationResult validateProviderHost(String? host) {
    if (host == null || host.isEmpty) {
      return ValidationResult.fieldErrors({
        'host': 'Host is required',
      });
    }

    // Basic URL validation
    try {
      Uri.parse(host);
    } catch (e) {
      return ValidationResult.fieldErrors({
        'host': 'Invalid URL format',
      });
    }

    return ValidationResult.success();
  }

  /// Validate provider port
  static ValidationResult validateProviderPort(dynamic port) {
    if (port == null) {
      return ValidationResult.fieldErrors({
        'port': 'Port is required',
      });
    }

    int? portNum;
    if (port is int) {
      portNum = port;
    } else if (port is String) {
      portNum = int.tryParse(port);
    }

    if (portNum == null) {
      return ValidationResult.fieldErrors({
        'port': 'Port must be a valid number',
      });
    }

    if (portNum < 1 || portNum > 65535) {
      return ValidationResult.fieldErrors({
        'port': 'Port must be between 1 and 65535',
      });
    }

    return ValidationResult.success();
  }

  /// Validate provider API key (optional but if provided must be non-empty)
  static ValidationResult validateProviderApiKey(String? apiKey) {
    if (apiKey != null && apiKey.isEmpty) {
      return ValidationResult.fieldErrors({
        'apiKey': 'API key cannot be empty if provided',
      });
    }

    return ValidationResult.success();
  }

  /// Validate provider configuration
  static ValidationResult validateProviderConfiguration({
    required String? host,
    required dynamic port,
    String? apiKey,
  }) {
    final errors = <String, String>{};

    // Validate host
    final hostResult = validateProviderHost(host);
    if (!hostResult.isValid) {
      errors.addAll(hostResult.errors);
    }

    // Validate port
    final portResult = validateProviderPort(port);
    if (!portResult.isValid) {
      errors.addAll(portResult.errors);
    }

    // Validate API key
    final apiKeyResult = validateProviderApiKey(apiKey);
    if (!apiKeyResult.isValid) {
      errors.addAll(apiKeyResult.errors);
    }

    if (errors.isNotEmpty) {
      return ValidationResult.fieldErrors(errors);
    }

    return ValidationResult.success();
  }

  /// Validate window position
  static ValidationResult validateWindowPosition(double? x, double? y) {
    if (x == null || y == null) {
      return ValidationResult.fieldErrors({
        'position': 'Window position must be specified',
      });
    }

    if (x < 0 || y < 0) {
      return ValidationResult.fieldErrors({
        'position': 'Window position cannot be negative',
      });
    }

    return ValidationResult.success();
  }

  /// Validate window size
  static ValidationResult validateWindowSize(double? width, double? height) {
    if (width == null || height == null) {
      return ValidationResult.fieldErrors({
        'size': 'Window size must be specified',
      });
    }

    if (width < 400 || height < 300) {
      return ValidationResult.fieldErrors({
        'size': 'Window size must be at least 400x300 pixels',
      });
    }

    if (width > 7680 || height > 4320) {
      return ValidationResult.fieldErrors({
        'size': 'Window size cannot exceed 7680x4320 pixels',
      });
    }

    return ValidationResult.success();
  }

  /// Validate import/export JSON settings
  static ValidationResult validateSettingsJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return ValidationResult.error('Settings file is empty');
    }

    // Validate that all values are serializable types
    try {
      _validateJsonSerializable(json);
    } catch (e) {
      return ValidationResult.error('Invalid settings format: $e');
    }

    return ValidationResult.success();
  }

  /// Helper to validate JSON is serializable
  static void _validateJsonSerializable(dynamic value) {
    if (value == null ||
        value is bool ||
        value is int ||
        value is double ||
        value is String) {
      return;
    }

    if (value is List) {
      for (final item in value) {
        _validateJsonSerializable(item);
      }
      return;
    }

    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw ArgumentError('Map keys must be strings');
        }
        _validateJsonSerializable(entry.value);
      }
      return;
    }

    throw ArgumentError('Unsupported type: ${value.runtimeType}');
  }

  /// Validate all settings together
  static ValidationResult validateAllSettings({
    String? theme,
    String? language,
    String? providerHost,
    dynamic providerPort,
    String? providerApiKey,
    double? windowX,
    double? windowY,
    double? windowWidth,
    double? windowHeight,
  }) {
    final errors = <String, String>{};

    // Validate theme if provided
    if (theme != null) {
      final themeResult = validateTheme(theme);
      if (!themeResult.isValid) {
        errors.addAll(themeResult.errors);
      }
    }

    // Validate language if provided
    if (language != null) {
      final languageResult = validateLanguage(language);
      if (!languageResult.isValid) {
        errors.addAll(languageResult.errors);
      }
    }

    // Validate provider config if any provider field is provided
    if (providerHost != null || providerPort != null) {
      final providerResult = validateProviderConfiguration(
        host: providerHost,
        port: providerPort,
        apiKey: providerApiKey,
      );
      if (!providerResult.isValid) {
        errors.addAll(providerResult.errors);
      }
    }

    // Validate window position if provided
    if (windowX != null || windowY != null) {
      final positionResult = validateWindowPosition(windowX, windowY);
      if (!positionResult.isValid) {
        errors.addAll(positionResult.errors);
      }
    }

    // Validate window size if provided
    if (windowWidth != null || windowHeight != null) {
      final sizeResult = validateWindowSize(windowWidth, windowHeight);
      if (!sizeResult.isValid) {
        errors.addAll(sizeResult.errors);
      }
    }

    if (errors.isNotEmpty) {
      return ValidationResult.fieldErrors(errors);
    }

    return ValidationResult.success();
  }
}
