# Admin Center Error Handling & Validation - Quick Reference

## Error Handling

### AdminErrorHandler

```dart
import '../utils/admin_error_handler.dart';

// Handle DioException
try {
  final response = await _dio.get('/api/admin/users');
} catch (e) {
  final error = AdminErrorHandler.handleDioException(e as DioException);
  AdminErrorHandler.logError(error, context: 'UserService');
  _setError(error.message);
}

// Handle payment gateway errors
try {
  await processPayment();
} catch (e) {
  final error = AdminErrorHandler.handlePaymentGatewayError(e);
  AdminSnackBar.showError(context, error.message);
}

// Handle validation errors
final error = AdminErrorHandler.handleValidationError(
  'Invalid email format',
  field: 'email',
);

// Handle generic errors
final error = AdminErrorHandler.handleGenericError(e);
```

### Error Types

- `authentication` - 401 errors, session expired
- `authorization` - 403 errors, insufficient permissions
- `validation` - 400, 422 errors, invalid input
- `notFound` - 404 errors, resource not found
- `serverError` - 500+ errors, server issues
- `paymentGateway` - Payment processing errors
- `network` - Connection, timeout errors
- `unknown` - Unexpected errors

## Form Validation

### Common Validators

```dart
import '../utils/admin_form_validators.dart';

// Email
TextFormField(
  validator: AdminFormValidators.validateEmail,
)

// Required field
TextFormField(
  validator: (value) => AdminFormValidators.validateRequired(
    value,
    fieldName: 'Username',
  ),
)

// Refund amount
TextFormField(
  validator: (value) => AdminFormValidators.validateRefundAmount(
    value,
    maxAmount: 100.00,
    minAmount: 0.01,
  ),
)

// Date range
final error = AdminFormValidators.validateDateRange(
  startDate: _startDate,
  endDate: _endDate,
  maxDate: DateTime.now(),
);

// Combine validators
TextFormField(
  validator: AdminFormValidators.combine([
    (value) => AdminFormValidators.validateRequired(value),
    (value) => AdminFormValidators.validateEmail(value),
  ]),
)
```

### All Available Validators

| Validator | Purpose |
|-----------|---------|
| `validateEmail` | Email format |
| `validateRequired` | Required field |
| `validateRefundAmount` | Refund amount with min/max |
| `validatePositiveNumber` | Positive numbers |
| `validateInteger` | Whole numbers |
| `validatePercentage` | 0-100 percentage |
| `validateDateRange` | Date range validation |
| `validateStartDate` | Start date |
| `validateEndDate` | End date |
| `validateLength` | Text length min/max |
| `validateUrl` | URL format |
| `validatePhoneNumber` | Phone number |
| `validateSelection` | Dropdown selection |
| `validateReason` | Reason field (min 10 chars) |
| `validatePassword` | Password strength |
| `validateCreditCard` | Credit card (Luhn) |
| `validateCVV` | CVV (3-4 digits) |
| `validateExpiryDate` | Expiry date (MM/YY) |

## Error Display Widgets

### Inline Messages

```dart
import '../widgets/admin_error_message.dart';

// Error message
AdminErrorMessage(
  errorMessage: _errorMessage,
  padding: const EdgeInsets.all(16),
)

// Success message
AdminSuccessMessage(
  message: 'Operation completed successfully',
)

// Warning message
AdminWarningMessage(
  message: 'This action cannot be undone',
)

// Info message
AdminInfoMessage(
  message: 'This feature is in beta',
)
```

### Snackbars

```dart
// Error snackbar
AdminSnackBar.showError(context, 'Failed to save changes');

// Success snackbar
AdminSnackBar.showSuccess(context, 'Changes saved successfully');

// Warning snackbar
AdminSnackBar.showWarning(context, 'Please review before submitting');

// Info snackbar
AdminSnackBar.showInfo(context, 'New feature available');
```

## Common Patterns

### Service Error Handling

```dart
class MyAdminService extends ChangeNotifier {
  String? _error;
  
  Future<void> performAction() async {
    try {
      _setError(null);
      final response = await _dio.post('/api/admin/action');
      // Success
    } catch (e) {
      final error = AdminErrorHandler.handleDioException(e as DioException);
      AdminErrorHandler.logError(error, context: 'MyAdminService');
      _setError(error.message);
    }
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
}
```

### Form Validation

```dart
class MyForm extends StatefulWidget {
  @override
  State<MyForm> createState() => _MyFormState();
}

class _MyFormState extends State<MyForm> {
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  
  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Additional validation
    final dateError = AdminFormValidators.validateDateRange(
      startDate: _startDate,
      endDate: _endDate,
    );
    
    if (dateError != null) {
      setState(() => _errorMessage = dateError);
      return;
    }
    
    // Submit form
  }
  
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AdminErrorMessage(errorMessage: _errorMessage),
          TextFormField(
            validator: AdminFormValidators.validateEmail,
          ),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
```

### Payment Error Handling

```dart
Future<void> processRefund() async {
  try {
    final result = await _paymentService.processRefund(
      transactionId: _transactionId,
      amount: _amount,
      reason: _reason,
    );
    
    if (result != null) {
      AdminSnackBar.showSuccess(context, 'Refund processed successfully');
    }
  } catch (e) {
    final error = AdminErrorHandler.handlePaymentGatewayError(e);
    AdminSnackBar.showError(context, error.message);
  }
}
```

## Best Practices

1. **Always handle errors in services:**
   ```dart
   try {
     // API call
   } catch (e) {
     final error = AdminErrorHandler.handleDioException(e as DioException);
     _setError(error.message);
   }
   ```

2. **Use appropriate validators:**
   ```dart
   // Don't just use validateRequired
   // Use specific validators for better UX
   TextFormField(
     validator: AdminFormValidators.validateEmail, // ✅ Good
   )
   ```

3. **Show user-friendly messages:**
   ```dart
   // Don't show raw error messages
   AdminSnackBar.showError(context, error.message); // ✅ Good
   ```

4. **Log errors for debugging:**
   ```dart
   AdminErrorHandler.logError(error, context: 'ServiceName');
   ```

5. **Validate before API calls:**
   ```dart
   // Validate locally first
   if (!_formKey.currentState!.validate()) {
     return;
   }
   // Then make API call
   ```

6. **Combine validators when needed:**
   ```dart
   validator: AdminFormValidators.combine([
     (value) => AdminFormValidators.validateRequired(value),
     (value) => AdminFormValidators.validateLength(value, minLength: 3),
   ]),
   ```

## Error Message Guidelines

- **Be specific:** "Email is required" not "Field is required"
- **Be actionable:** "Please enter a valid email address"
- **Be concise:** Keep messages short and clear
- **Be helpful:** Suggest what the user should do
- **Be consistent:** Use the same terminology throughout

## Testing

```dart
// Test validators
test('validateEmail returns error for invalid email', () {
  final error = AdminFormValidators.validateEmail('invalid');
  expect(error, isNotNull);
});

// Test error handler
test('handleDioException returns correct error type', () {
  final dioError = DioException(
    requestOptions: RequestOptions(path: '/test'),
    response: Response(
      requestOptions: RequestOptions(path: '/test'),
      statusCode: 401,
    ),
  );
  
  final error = AdminErrorHandler.handleDioException(dioError);
  expect(error.type, AdminErrorType.authentication);
});
```

## Troubleshooting

**Q: Error messages not showing?**
- Check if error is null or empty
- Verify widget is in the widget tree
- Check if setState is called

**Q: Validation not working?**
- Ensure Form widget has a key
- Call validate() before checking form state
- Check validator return values (null = valid)

**Q: Snackbar not appearing?**
- Ensure Scaffold is in the widget tree
- Check if another snackbar is already showing
- Verify context is valid

**Q: Error logging not working?**
- Check if app is in debug mode
- Verify debugPrint is not disabled
- Check console output
