import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/color_extensions.dart';

/// Accessible loading animation component with reduced motion support
class LoadingAnimation extends StatefulWidget {
  final String message;
  final double size;
  final bool showMessage;
  final Color? color;
  final bool reduceMotion;

  const LoadingAnimation({
    super.key,
    this.message = 'Loading...',
    this.size = 24.0,
    this.showMessage = true,
    this.color,
    this.reduceMotion = false,
  });

  @override
  State<LoadingAnimation> createState() => _LoadingAnimationState();
}

class _LoadingAnimationState extends State<LoadingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.reduceMotion ? 100 : 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    if (!widget.reduceMotion) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.message,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: widget.reduceMotion
                ? _buildStaticIndicator()
                : _buildAnimatedIndicator(),
          ),
          if (widget.showMessage) ...[
            SizedBox(height: AppTheme.spacingS),
            Text(
              widget.message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimatedIndicator() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CircularProgressIndicator(
          value: _animation.value,
          strokeWidth: 3.0,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.color ?? AppTheme.primaryColor,
          ),
          backgroundColor: AppTheme.backgroundMain,
        );
      },
    );
  }

  Widget _buildStaticIndicator() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.color ?? AppTheme.primaryColor,
          width: 3.0,
        ),
      ),
      child: Center(
        child: Container(
          width: widget.size * 0.3,
          height: widget.size * 0.3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color ?? AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

/// Progress indicator with accessibility support
class AccessibleProgressIndicator extends StatelessWidget {
  final double value;
  final String label;
  final bool showPercentage;
  final Color? color;
  final double height;

  const AccessibleProgressIndicator({
    super.key,
    required this.value,
    required this.label,
    this.showPercentage = true,
    this.color,
    this.height = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value * 100).round();

    return Semantics(
      label: '$label: $percentage percent complete',
      value: '$percentage%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (showPercentage)
                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
                ),
            ],
          ),
          SizedBox(height: AppTheme.spacingXS),
          LinearProgressIndicator(
            value: value,
            backgroundColor: AppTheme.backgroundMain,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppTheme.primaryColor,
            ),
            minHeight: height,
          ),
        ],
      ),
    );
  }
}

/// Success animation with accessibility support
class SuccessAnimation extends StatefulWidget {
  final String message;
  final double size;
  final bool reduceMotion;
  final VoidCallback? onComplete;

  const SuccessAnimation({
    super.key,
    this.message = 'Success!',
    this.size = 64.0,
    this.reduceMotion = false,
    this.onComplete,
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _checkController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: Duration(milliseconds: widget.reduceMotion ? 100 : 600),
      vsync: this,
    );

    _checkController = AnimationController(
      duration: Duration(milliseconds: widget.reduceMotion ? 100 : 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeInOut),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    if (widget.reduceMotion) {
      _scaleController.value = 1.0;
      _checkController.value = 1.0;
      widget.onComplete?.call();
    } else {
      await _scaleController.forward();
      await _checkController.forward();
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.message,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.successColor,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _checkAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: CheckmarkPainter(
                          progress: _checkAnimation.value,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          SizedBox(height: AppTheme.spacingM),
          Text(
            widget.message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.successColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Custom painter for animated checkmark
class CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final checkSize = size.width * 0.3;

    // Define checkmark path
    final path = Path();
    path.moveTo(center.dx - checkSize, center.dy);
    path.lineTo(center.dx - checkSize * 0.2, center.dy + checkSize * 0.6);
    path.lineTo(center.dx + checkSize, center.dy - checkSize * 0.4);

    // Draw checkmark with progress
    final pathMetrics = path.computeMetrics();
    for (final pathMetric in pathMetrics) {
      final extractedPath = pathMetric.extractPath(
        0.0,
        pathMetric.length * progress,
      );
      canvas.drawPath(extractedPath, paint);
    }
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Error animation with accessibility support
class ErrorAnimation extends StatefulWidget {
  final String message;
  final double size;
  final bool reduceMotion;
  final VoidCallback? onRetry;

  const ErrorAnimation({
    super.key,
    this.message = 'Error occurred',
    this.size = 64.0,
    this.reduceMotion = false,
    this.onRetry,
  });

  @override
  State<ErrorAnimation> createState() => _ErrorAnimationState();
}

class _ErrorAnimationState extends State<ErrorAnimation>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: Duration(milliseconds: widget.reduceMotion ? 100 : 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    if (!widget.reduceMotion) {
      _shakeController.repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _shakeController.stop();
        }
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Error: ${widget.message}',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value * 2, 0),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.dangerColor,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.dangerColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: widget.size * 0.5,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: AppTheme.spacingM),
          Text(
            widget.message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.dangerColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.onRetry != null) ...[
            SizedBox(height: AppTheme.spacingM),
            Semantics(
              label: 'Retry action',
              button: true,
              child: ElevatedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 44),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
