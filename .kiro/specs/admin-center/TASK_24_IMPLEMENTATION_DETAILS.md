# Task 24: Error Handling and Validation - Implementation Details

## Overview

This document provides detailed implementation information for the Admin Center error handling and validation system.

## Architecture

### Error Handling Flow

```
User Action
    ↓
Service Method
    ↓
API Call (Dio)
    ↓
[Success] → Update State → Notify UI
    ↓
[Error] → DioException
    ↓
AdminErrorHandler.handleDioException()
    ↓
AdminError (with type and message)
    ↓
Service._setError() → notifyListeners()
    ↓
UI displays error (AdminErrorMessage or AdminSnackBar)
```

### Validation Flow

```
User Input
    ↓
TextFormField
    ↓
validator: AdminFormValidators.validateX()
    ↓
[Valid] → null (no error)
    ↓
[Invalid] → Error message string
    ↓
Form displays inline error
    ↓
Form.validate() checks all fields
    ↓
[All valid] → Submit form
    ↓
[Any invalid] → Prevent submission
```

## AdminErrorHandler Implementation

### Error Type Mapping

| HTTP Status | AdminErrorType | User Message |
|-------------|----------------|--------------|
| 400 | validation | "Invalid request. Please check your input." |
| 401 | authentication | "Your session has expired. Please log in again." |
| 403 | authorization | "You do not have permission to perform this action." |
| 404 | notFound | "The requested resource was not found." |
| 409 | validation | "This operation conflicts with existing data." |
| 422 | validation | "Validation failed. Please check your input." |
| 429 | serverError | "Too many requests. Please wait a moment and try again." |
| 500-504 | serverError | "Server error. Please try again later or contact support." |

### DioException Type Mapping

| DioExceptionType | AdminErrorType | User Message |
|------------------|----------------|--------------|
| connectionTimeout | network | "Connection timeout. Please check your internet connection." |
| sendTimeout | network | "Connection timeout. Please check your internet connection." |
| receiveTimeout | network | "Connection timeout. Please check your internet connection." |
| badResponse | (varies) | Based on status code |
| cancel | unknown | "Request was cancelled." |
| connectionError | network | "Unable to connect to the server. Please check your internet connection." |
| badCertificate | network | "Security certificate error. Please contact support." |
| unknown | unknown | "An unexpected error occurred. Please try again." |

### Payment Gateway Error Mapping

| Gateway Error | User Message |
|---------------|--------------|
| card_declined | "The card was declined. Please try a different payment method." |
| insufficient_funds | "Insufficient funds. Please try a different payment method." |
| expired_card | "The card has expired. Please use a different payment method." |
| incorrect_cvc | "Incorrect security code. Please check and try again." |
| processing_error | "Payment processing error. Please try again." |
| rate_limit | "Too many payment attempts. Please wait a moment and try again." |
| refund | "Refund processing failed. Please contact support." |

## AdminFormValidators Implementation

### Validator Categories

#### 1. Basic Validators
- **Purpose:** Common field validation
- **Examples:** email, required, selection
- **Return:** `null` if valid, error message string if invalid

#### 2. Numeric Validators
- **Purpose:** Number and amount validation
- **Features:** Min/max bounds, decimal places, positive numbers
- **Examples:** refundAmount, positiveNumber, integer, percentage

#### 3. Date Validators
- **Purpose:** Date and date range validation
- **Features:** Min/max dates, range limits, chronological order
- **Examples:** dateRange, startDate, endDate

#### 4. Text Validators
- **Purpose:** Text format and length validation
- **Features:** Min/max length, format patterns
- **Examples:** length, url, phoneNumber

#### 5. Payment Validators
- **Purpose:** Payment information validation
- **Features:** Luhn algorithm, format validation
- **Examples:** creditCard, cvv, expiryDate

#### 6. Security Validators
- **Purpose:** Security-related validation
- **Features:** Strength requirements, complexity rules
- **Examples:** password

### Validation Rules

#### Email Validation
```dart
Regex: r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
Rules:
- Must contain @ symbol
- Must have domain with at least 2 character TLD
- Allows common special characters (. _ % + -)
```

#### Refund Amount Validation
```dart
Rules:
- Must be a valid number
- Must be >= minAmount (default 0.01)
- Must be <= maxAmount (transaction amount)
- Cannot have more than 2 decimal places
```

#### Date Range Validation
```dart
Rules:
- Start date must be before end date
- Start date must be >= minDate (if specified)
- End date must be <= maxDate (if specified)
- Range cannot exceed 1 year (365 days)
```

#### Password Validation
```dart
Rules:
- Minimum 8 characters
- At least one uppercase letter [A-Z]
- At least one lowercase letter [a-z]
- At least one number [0-9]
- At least one special character [!@#$%^&*(),.?":{}|<>]
```

#### Credit Card Validation
```dart
Rules:
- Only digits (spaces and dashes removed)
- Length between 13-19 digits
- Must pass Luhn algorithm check
```

### Luhn Algorithm Implementation

```dart
static bool _luhnCheck(String cardNumber) {
  int sum = 0;
  bool alternate = false;

  // Process digits from right to left
  for (int i = cardNumber.length - 1; i >= 0; i--) {
    int digit = int.parse(cardNumber[i]);

    if (alternate) {
      digit *= 2;
      if (digit > 9) {
        digit -= 9; // Same as summing the digits
      }
    }

    sum += digit;
    alternate = !alternate;
  }

  return sum % 10 == 0;
}
```

## AdminErrorMessage Widgets

### Widget Hierarchy

```
AdminErrorMessage (base error widget)
AdminSuccessMessage (success variant)
AdminWarningMessage (warning variant)
AdminInfoMessage (info variant)
```

### Styling

#### Error Message
- Background: `theme.colorScheme.errorContainer`
- Text: `theme.colorScheme.onErrorContainer`
- Border: `theme.colorScheme.error` with 30% opacity
- Icon: `Icons.error_outline`

#### Success Message
- Background: `Colors.green.shade50`
- Text: `Colors.green.shade900`
- Border: `Colors.green` with 30% opacity
- Icon: `Icons.check_circle_outline`

#### Warning Message
- Background: `Colors.orange.shade50`
- Text: `Colors.orange.shade900`
- Border: `Colors.orange` with 30% opacity
- Icon: `Icons.warning_amber_outlined`

#### Info Message
- Background: `Colors.blue.shade50`
- Text: `Colors.blue.shade900`
- Border: `Colors.blue` with 30% opacity
- Icon: `Icons.info_outline`

### Snackbar Configuration

```dart
SnackBar(
  content: Row with icon and text,
  backgroundColor: Based on type,
  behavior: SnackBarBehavior.floating,
  duration: 3-4 seconds,
  action: Dismiss button (error only),
)
```

## Integration Patterns

### Service Integration

```dart
class AdminCenterService extends ChangeNotifier {
  String? _error;
  bool _isLoading = false;

  Future<void> performAction() async {
    try {
      _setLoading(true);
      _setError(null);
      
      final response = await _dio.post('/api/admin/action');
      
      // Success handling
      _setLoading(false);
      
    } catch (e) {
      _setLoading(false);
      
      if (e is DioException) {
        final error = AdminErrorHandler.handleDioException(e);
        AdminErrorHandler.logError(error, context: 'AdminCenterService');
        _setError(error.message);
      } else {
        final error = AdminErrorHandler.handleGenericError(e);
        _setError(error.message);
      }
    }
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
```

### UI Integration

```dart
class MyAdminForm extends StatefulWidget {
  @override
  State<MyAdminForm> createState() => _MyAdminFormState();
}

class _MyAdminFormState extends State<MyAdminForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _errorMessage;
  String? _successMessage;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error message display
          if (_errorMessage != null)
            AdminErrorMessage(
              errorMessage: _errorMessage,
              padding: const EdgeInsets.only(bottom: 16),
            ),
          
          // Success message display
          if (_successMessage != null)
            AdminSuccessMessage(
              message: _successMessage,
              padding: const EdgeInsets.only(bottom: 16),
            ),
          
          // Form fields with validation
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Refund Amount',
              prefixText: '\$',
            ),
            keyboardType: TextInputType.number,
            validator: (value) => AdminFormValidators.validateRefundAmount(
              value,
              maxAmount: widget.maxAmount,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Submit button
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    // Clear previous messages
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation
    final amount = double.parse(_amountController.text);
    if (amount > widget.maxAmount) {
      setState(() {
        _errorMessage = 'Amount exceeds maximum refundable amount';
      });
      return;
    }

    // Submit
    _performSubmit();
  }

  Future<void> _performSubmit() async {
    try {
      await widget.onSubmit(_amountController.text);
      
      setState(() {
        _successMessage = 'Refund processed successfully';
      });
      
      // Or use snackbar
      AdminSnackBar.showSuccess(context, 'Refund processed successfully');
      
    } catch (e) {
      final error = AdminErrorHandler.handlePaymentGatewayError(e);
      
      setState(() {
        _errorMessage = error.message;
      });
      
      // Or use snackbar
      AdminSnackBar.showError(context, error.message);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
```

## Error Logging

### Debug Mode Logging

```dart
AdminErrorHandler.logError(error, context: 'ServiceName');

// Output:
// [ServiceName] authentication: Your session has expired. Please log in again.
// [ServiceName] Technical: DioException [connectionTimeout]: ...
// [ServiceName] Status Code: 401
```

### Production Mode

- Technical details are not included in user-facing messages
- Only user-friendly messages are displayed
- Errors can be sent to logging service (e.g., Sentry, Firebase Crashlytics)

## Performance Considerations

### Validation Performance

- All validators are synchronous
- Regex compilation is done once per validator call
- No network calls in validators
- Minimal memory allocation

### Error Handling Performance

- Error conversion is lightweight
- No async operations
- Minimal string manipulation
- Debug logging only in debug mode

## Security Considerations

### Input Validation

- All user input is validated before API calls
- Prevents injection attacks through validation
- Credit card validation uses industry-standard Luhn algorithm
- Password validation enforces strong passwords

### Error Messages

- No sensitive information in error messages
- Technical details only in debug mode
- Generic messages for security errors
- No stack traces in production

## Testing Strategy

### Unit Tests

```dart
// Validator tests
test('validateEmail returns null for valid email', () {
  expect(AdminFormValidators.validateEmail('test@example.com'), isNull);
});

test('validateEmail returns error for invalid email', () {
  expect(AdminFormValidators.validateEmail('invalid'), isNotNull);
});

// Error handler tests
test('handleDioException returns authentication error for 401', () {
  final dioError = DioException(
    requestOptions: RequestOptions(path: '/test'),
    response: Response(
      requestOptions: RequestOptions(path: '/test'),
      statusCode: 401,
    ),
  );
  
  final error = AdminErrorHandler.handleDioException(dioError);
  expect(error.type, AdminErrorType.authentication);
  expect(error.statusCode, 401);
});
```

### Widget Tests

```dart
testWidgets('AdminErrorMessage displays error', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminErrorMessage(
          errorMessage: 'Test error',
        ),
      ),
    ),
  );
  
  expect(find.text('Test error'), findsOneWidget);
  expect(find.byIcon(Icons.error_outline), findsOneWidget);
});
```

### Integration Tests

```dart
testWidgets('Form validation prevents submission', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Enter invalid email
  await tester.enterText(find.byType(TextFormField), 'invalid');
  
  // Try to submit
  await tester.tap(find.text('Submit'));
  await tester.pump();
  
  // Verify error message is shown
  expect(find.text('Please enter a valid email address'), findsOneWidget);
});
```

## Maintenance

### Adding New Validators

1. Add validator function to `AdminFormValidators`
2. Follow naming convention: `validateX()`
3. Return `null` for valid, error message for invalid
4. Add documentation comment
5. Add to quick reference guide
6. Add unit tests

### Adding New Error Types

1. Add to `AdminErrorType` enum
2. Add handling in `AdminErrorHandler`
3. Add user-friendly message
4. Update error type mapping table
5. Add unit tests

### Updating Error Messages

1. Update message in `AdminErrorHandler`
2. Ensure message is user-friendly and actionable
3. Test with real users if possible
4. Update documentation

## Troubleshooting

### Common Issues

**Issue:** Validator not working
- **Solution:** Check if Form has a key and validate() is called

**Issue:** Error message not displaying
- **Solution:** Check if error is null, verify setState is called

**Issue:** Snackbar not showing
- **Solution:** Ensure Scaffold is in widget tree, check context

**Issue:** Wrong error type
- **Solution:** Check status code mapping, verify DioException type

## Future Enhancements

1. **Internationalization:**
   - Add i18n support for error messages
   - Translate validation messages

2. **Custom Validators:**
   - Allow custom validator registration
   - Validator composition utilities

3. **Error Analytics:**
   - Track error frequency
   - Monitor error patterns
   - Alert on error spikes

4. **Enhanced Logging:**
   - Integration with logging services
   - Error reporting to backend
   - User feedback collection

## Conclusion

The error handling and validation system provides a robust foundation for the Admin Center. It ensures consistent error handling, user-friendly validation, and maintainable code patterns throughout the application.
