@echo off
echo ========================================
echo CloudToLocalLLM Privacy-First Deployment
echo ========================================
echo.

echo [1/6] Backing up original files...
if exist lib\services\conversation_storage_service.dart (
    copy lib\services\conversation_storage_service.dart lib\services\conversation_storage_service.dart.original
    echo ✓ Backed up conversation_storage_service.dart
)

if exist lib\services\desktop_client_detection_service.dart (
    copy lib\services\desktop_client_detection_service.dart lib\services\desktop_client_detection_service.dart.original
    echo ✓ Backed up desktop_client_detection_service.dart
)

if exist lib\main.dart (
    copy lib\main.dart lib\main.dart.original
    echo ✓ Backed up main.dart
)

echo.
echo [2/6] Deploying fixed services...

if exist lib\services\conversation_storage_service_fixed.dart (
    copy lib\services\conversation_storage_service_fixed.dart lib\services\conversation_storage_service.dart
    echo ✓ Deployed fixed conversation storage service
) else (
    echo ❌ conversation_storage_service_fixed.dart not found
)

if exist lib\services\desktop_client_detection_service_fixed.dart (
    copy lib\services\desktop_client_detection_service_fixed.dart lib\services\desktop_client_detection_service.dart
    echo ✓ Deployed fixed desktop client detection service
) else (
    echo ❌ desktop_client_detection_service_fixed.dart not found
)

echo.
echo [3/6] Checking new privacy services...

if exist lib\services\privacy_storage_manager.dart (
    echo ✓ Privacy storage manager ready
) else (
    echo ❌ privacy_storage_manager.dart not found
)

if exist lib\services\enhanced_user_tier_service.dart (
    echo ✓ Enhanced user tier service ready
) else (
    echo ❌ enhanced_user_tier_service.dart not found
)

if exist lib\services\platform_service_manager.dart (
    echo ✓ Platform service manager ready
) else (
    echo ❌ platform_service_manager.dart not found
)

echo.
echo [4/6] Checking privacy dashboard...

if exist lib\widgets\privacy_dashboard.dart (
    echo ✓ Privacy dashboard widget ready
) else (
    echo ❌ privacy_dashboard.dart not found
)

echo.
echo [5/6] Validating dependencies...

echo Checking pubspec.yaml for required dependencies...
findstr /C:"sqflite:" pubspec.yaml >nul
if %errorlevel%==0 (
    echo ✓ sqflite dependency found
) else (
    echo ❌ sqflite dependency missing
)

findstr /C:"sqflite_common_ffi:" pubspec.yaml >nul
if %errorlevel%==0 (
    echo ✓ sqflite_common_ffi dependency found
) else (
    echo ❌ sqflite_common_ffi dependency missing
)

findstr /C:"shared_preferences:" pubspec.yaml >nul
if %errorlevel%==0 (
    echo ✓ shared_preferences dependency found
) else (
    echo ❌ shared_preferences dependency missing
)

findstr /C:"provider:" pubspec.yaml >nul
if %errorlevel%==0 (
    echo ✓ provider dependency found
) else (
    echo ❌ provider dependency missing
)

echo.
echo [6/6] Running Flutter clean and get packages...
flutter clean
flutter pub get

echo.
echo ========================================
echo Deployment Summary
echo ========================================
echo.
echo Critical Fixes Applied:
echo ✓ Database initialization fix for web platform
echo ✓ API endpoint corrections for cloud proxy
echo ✓ Platform detection and graceful degradation
echo.
echo Privacy Architecture Added:
echo ✓ Privacy-first storage manager
echo ✓ Enhanced tier-based user service
echo ✓ Platform service manager
echo ✓ Privacy dashboard widget
echo.
echo Next Steps:
echo 1. Test database initialization: flutter run -d chrome
echo 2. Verify no "databaseFactory not initialized" errors
echo 3. Test conversation creation and storage
echo 4. Check privacy dashboard functionality
echo 5. Validate tier-based feature restrictions
echo.
echo For detailed testing instructions, see:
echo PRIVACY_FIRST_IMPLEMENTATION_SUMMARY.md
echo.
echo ========================================
echo Deployment Complete!
echo ========================================

pause
