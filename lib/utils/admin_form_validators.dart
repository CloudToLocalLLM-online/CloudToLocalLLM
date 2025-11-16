/// Form validation utilities for admin forms
class AdminFormValidators {
  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validate required field
  static String? validateRequired(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  /// Validate refund amount
  static String? validateRefundAmount(
    String? value, {
    required double maxAmount,
    double minAmount = 0.01,
  }) {
    if (value == null || value.isEmpty) {
      return 'Refund amount is required';
    }

    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Please enter a valid amount';
    }

    if (amount < minAmount) {
      return 'Refund amount must be at least \$${minAmount.toStringAsFixed(2)}';
    }

    if (amount > maxAmount) {
      return 'Refund amount cannot exceed \$${maxAmount.toStringAsFixed(2)}';
    }

    // Check for more than 2 decimal places
    if (value.contains('.') && value.split('.')[1].length > 2) {
      return 'Amount cannot have more than 2 decimal places';
    }

    return null;
  }

  /// Validate positive number
  static String? validatePositiveNumber(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }

    final number = double.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }

    if (number <= 0) {
      return '${fieldName ?? 'Value'} must be greater than 0';
    }

    return null;
  }

  /// Validate integer
  static String? validateInteger(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }

    final number = int.tryParse(value);
    if (number == null) {
      return 'Please enter a valid whole number';
    }

    return null;
  }

  /// Validate date range
  static String? validateDateRange({
    required DateTime? startDate,
    required DateTime? endDate,
    DateTime? minDate,
    DateTime? maxDate,
  }) {
    if (startDate == null) {
      return 'Start date is required';
    }

    if (endDate == null) {
      return 'End date is required';
    }

    if (startDate.isAfter(endDate)) {
      return 'Start date must be before end date';
    }

    if (minDate != null && startDate.isBefore(minDate)) {
      return 'Start date cannot be before ${_formatDate(minDate)}';
    }

    if (maxDate != null && endDate.isAfter(maxDate)) {
      return 'End date cannot be after ${_formatDate(maxDate)}';
    }

    // Check if date range is too large (e.g., more than 1 year)
    final difference = endDate.difference(startDate);
    if (difference.inDays > 365) {
      return 'Date range cannot exceed 1 year';
    }

    return null;
  }

  /// Validate start date
  static String? validateStartDate(
    DateTime? value, {
    DateTime? endDate,
    DateTime? minDate,
  }) {
    if (value == null) {
      return 'Start date is required';
    }

    if (minDate != null && value.isBefore(minDate)) {
      return 'Start date cannot be before ${_formatDate(minDate)}';
    }

    if (endDate != null && value.isAfter(endDate)) {
      return 'Start date must be before end date';
    }

    return null;
  }

  /// Validate end date
  static String? validateEndDate(
    DateTime? value, {
    DateTime? startDate,
    DateTime? maxDate,
  }) {
    if (value == null) {
      return 'End date is required';
    }

    if (startDate != null && value.isBefore(startDate)) {
      return 'End date must be after start date';
    }

    if (maxDate != null && value.isAfter(maxDate)) {
      return 'End date cannot be after ${_formatDate(maxDate)}';
    }

    return null;
  }

  /// Validate text length
  static String? validateLength(
    String? value, {
    int? minLength,
    int? maxLength,
    String? fieldName,
  }) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }

    if (minLength != null && value.length < minLength) {
      return '${fieldName ?? 'This field'} must be at least $minLength characters';
    }

    if (maxLength != null && value.length > maxLength) {
      return '${fieldName ?? 'This field'} cannot exceed $maxLength characters';
    }

    return null;
  }

  /// Validate URL format
  static String? validateUrl(String? value, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'URL is required' : null;
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value)) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  /// Validate phone number (basic validation)
  static String? validatePhoneNumber(String? value, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Phone number is required' : null;
    }

    // Remove common formatting characters
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

    // Check if it contains only digits
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Phone number can only contain digits';
    }

    // Check length (10-15 digits is typical for international numbers)
    if (cleaned.length < 10 || cleaned.length > 15) {
      return 'Phone number must be between 10 and 15 digits';
    }

    return null;
  }

  /// Validate dropdown selection
  static String? validateSelection(dynamic value, {String? fieldName}) {
    if (value == null) {
      return 'Please select ${fieldName ?? 'an option'}';
    }
    return null;
  }

  /// Validate reason field (for suspensions, refunds, etc.)
  static String? validateReason(String? value, {int minLength = 10}) {
    if (value == null || value.trim().isEmpty) {
      return 'Reason is required';
    }

    if (value.trim().length < minLength) {
      return 'Reason must be at least $minLength characters';
    }

    return null;
  }

  /// Validate password strength (for admin password changes)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  /// Validate percentage (0-100)
  static String? validatePercentage(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'Percentage'} is required';
    }

    final number = double.tryParse(value);
    if (number == null) {
      return 'Please enter a valid percentage';
    }

    if (number < 0 || number > 100) {
      return 'Percentage must be between 0 and 100';
    }

    return null;
  }

  /// Validate credit card number (basic Luhn algorithm)
  static String? validateCreditCard(String? value) {
    if (value == null || value.isEmpty) {
      return 'Card number is required';
    }

    // Remove spaces and dashes
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');

    // Check if it contains only digits
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Card number can only contain digits';
    }

    // Check length (13-19 digits for most cards)
    if (cleaned.length < 13 || cleaned.length > 19) {
      return 'Invalid card number length';
    }

    // Luhn algorithm validation
    if (!_luhnCheck(cleaned)) {
      return 'Invalid card number';
    }

    return null;
  }

  /// Validate CVV
  static String? validateCVV(String? value) {
    if (value == null || value.isEmpty) {
      return 'CVV is required';
    }

    if (!RegExp(r'^\d{3,4}$').hasMatch(value)) {
      return 'CVV must be 3 or 4 digits';
    }

    return null;
  }

  /// Validate expiry date (MM/YY format)
  static String? validateExpiryDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Expiry date is required';
    }

    final parts = value.split('/');
    if (parts.length != 2) {
      return 'Format must be MM/YY';
    }

    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);

    if (month == null || year == null) {
      return 'Invalid expiry date';
    }

    if (month < 1 || month > 12) {
      return 'Invalid month';
    }

    // Convert YY to YYYY
    final fullYear = year < 100 ? 2000 + year : year;
    final expiryDate = DateTime(fullYear, month);
    final now = DateTime.now();

    if (expiryDate.isBefore(DateTime(now.year, now.month))) {
      return 'Card has expired';
    }

    return null;
  }

  // Helper methods

  /// Format date for display
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Luhn algorithm for credit card validation
  static bool _luhnCheck(String cardNumber) {
    int sum = 0;
    bool alternate = false;

    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  /// Combine multiple validators
  static String? Function(String?) combine(
    List<String? Function(String?)> validators,
  ) {
    return (value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) {
          return error;
        }
      }
      return null;
    };
  }
}
