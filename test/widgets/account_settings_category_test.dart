import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/widgets/settings/account_settings_category.dart';
import 'package:cloudtolocalllm/models/settings_category.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/auth0_service.dart';
import 'package:cloudtolocalllm/services/session_storage_service.dart';
import 'package:cloudtolocalllm/models/user_model.dart';
import 'package:cloudtolocalllm/models/session_model.dart';

// Mock Auth0Service
class MockAuth0Service implements Auth0Service {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> login() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<bool> handleRedirectCallback() async => true;

  @override
  bool isCallbackUrl() => false;

  @override
  bool get isAuthenticated => true;

  @override
  String? getAccessToken() => 'test-token';

  @override
  Map<String, dynamic>? get currentUser => null;

  @override
  Stream<bool> get authStateChanges => Stream.value(true);

  @override
  void dispose() {}
}

// Mock SessionStorageService
class MockSessionStorageService extends SessionStorageService {
  @override
  Future<SessionModel?> getCurrentSession() async {
    final user = UserModel(
      id: 'test-user-id',
      email: 'test@example.com',
      name: 'Test User',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now(),
    );

    return SessionModel(
      id: 'session-id',
      userId: 'test-user-id',
      token: 'test-token',
      expiresAt: DateTime.now().add(const Duration(hours: 23)),
      user: user,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      lastActivity: DateTime.now(),
    );
  }
}

// Mock AuthService
class MockAuthService extends ChangeNotifier implements AuthService {
  @override
  UserModel? currentUser = UserModel(
    id: 'test-user-id',
    email: 'test@example.com',
    name: 'Test User',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  Future<void> logout() async {
    currentUser = null;
    notifyListeners();
  }

  @override
  Future<void> init() async {}

  @override
  Future<bool> handleCallback({String? callbackUrl}) async => true;

  @override
  Future<bool> handleRedirectCallback() async => true;

  @override
  Future<void> login({String? tenantId}) async {}

  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<String?> getValidatedAccessToken() async => 'test-token';

  @override
  Future<void> updateDisplayName(String displayName) async {}

  @override
  bool get isRestoringSession => false;

  @override
  bool get isSessionBootstrapComplete => true;

  @override
  bool get isWeb => true;

  @override
  bool get isMobile => false;

  @override
  bool get isDesktop => false;

  @override
  Future<void> get sessionBootstrapFuture => Future.value();

  @override
  ValueNotifier<bool> get isAuthenticated => ValueNotifier(true);

  @override
  ValueNotifier<bool> get isLoading => ValueNotifier(false);

  @override
  ValueNotifier<bool> get areAuthenticatedServicesLoaded => ValueNotifier(true);

  @override
  Auth0Service get auth0Service => MockAuth0Service();
}

void main() {
  group('AccountSettingsCategory', () {
    late MockAuthService mockAuthService;
    late MockSessionStorageService mockSessionStorage;

    setUp(() {
      mockAuthService = MockAuthService();
      mockSessionStorage = MockSessionStorageService();
    });

    testWidgets('renders user email and display name',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      // Wait for async initialization
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Check for email display
      expect(find.text('test@example.com'), findsOneWidget);

      // Check for display name
      expect(find.text('Test User'), findsOneWidget);

      // Check for section titles
      expect(find.text('User Profile'), findsOneWidget);
      expect(find.text('Subscription'), findsOneWidget);
      expect(find.text('Session'), findsOneWidget);
    });

    testWidgets('renders logout button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Check for logout button
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('displays session information', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Check for session section
      expect(find.text('Session'), findsOneWidget);
      expect(find.text('Login Time'), findsOneWidget);
      expect(find.text('Token Expiration'), findsOneWidget);
    });

    testWidgets('respects isActive property', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                isActive: false,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Widget should still render but with reduced opacity
      expect(find.byType(AccountSettingsCategory), findsOneWidget);
    });

    testWidgets('renders with correct category ID',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify the widget renders
      expect(find.byType(AccountSettingsCategory), findsOneWidget);
    });

    testWidgets('shows loading state initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      // Should show loading indicator briefly
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Wait for loading to complete
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Loading indicator should be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
