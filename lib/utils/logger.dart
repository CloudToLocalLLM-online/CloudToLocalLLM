import 'package:logger/logger.dart';

final AppLogger appLogger = AppLogger._internal();

class AppLogger {
  AppLogger._internal()
      : _logger = Logger(
          printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 5,
            lineLength: 90,
            colors: false,
            printEmojis: false,
            noBoxingByDefault: true,
          ),
        );

  final Logger _logger;

  void debug(String message) => _logger.d(message);

  void info(String message) => _logger.i(message);

  void warning(String message) => _logger.w(message);

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
