import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Animated step transition with accessibility support
class StepTransition extends StatefulWidget {
  final Widget child;
  final int currentStep;
  final bool reduceMotion;
  final Duration duration;

  const StepTransition({
    super.key,
    required this.child,
    required this.currentStep,
    this.reduceMotion = false,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<StepTransition> createState() => _StepTransitionState();
}

class _StepTransitionState extends State<StepTransition>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _previousStep = 0;

  @override
  void initState() {
    super.initState();
    _previousStep = widget.currentStep;

    _controller = AnimationController(
      duration: widget.reduceMotion
          ? const Duration(milliseconds: 50)
          : widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void didUpdateWidget(StepTransition oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentStep != widget.currentStep) {
      _previousStep = oldWidget.currentStep;

      if (widget.reduceMotion) {
        // Skip animation for reduced motion
        _controller.value = 1.0;
      } else {
        // Determine slide direction based on step change
        final isForward = widget.currentStep > _previousStep;
        _slideAnimation =
            Tween<Offset>(
              begin: isForward
                  ? const Offset(0.3, 0.0)
                  : const Offset(-0.3, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            );

        _controller.reset();
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Animated progress bar with smooth transitions
class AnimatedProgressBar extends StatefulWidget {
  final double value;
  final Color? backgroundColor;
  final Color? valueColor;
  final double height;
  final bool reduceMotion;
  final Duration duration;
  final String? semanticLabel;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.backgroundColor,
    this.valueColor,
    this.height = 4.0,
    this.reduceMotion = false,
    this.duration = const Duration(milliseconds: 500),
    this.semanticLabel,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.reduceMotion
          ? const Duration(milliseconds: 50)
          : widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: _previousValue,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;

      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

      if (widget.reduceMotion) {
        _controller.value = 1.0;
      } else {
        _controller.reset();
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = (widget.value * 100).round();

    return Semantics(
      label: widget.semanticLabel ?? 'Progress: $progressPercent percent',
      value: '$progressPercent%',
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return LinearProgressIndicator(
            value: _animation.value,
            backgroundColor: widget.backgroundColor ?? AppTheme.backgroundMain,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.valueColor ?? AppTheme.primaryColor,
            ),
            minHeight: widget.height,
          );
        },
      ),
    );
  }
}

/// Celebration animation for setup completion
class CelebrationAnimation extends StatefulWidget {
  final String message;
  final bool reduceMotion;
  final VoidCallback? onComplete;

  const CelebrationAnimation({
    super.key,
    this.message = 'Setup Complete!',
    this.reduceMotion = false,
    this.onComplete,
  });

  @override
  State<CelebrationAnimation> createState() => _CelebrationAnimationState();
}

class _CelebrationAnimationState extends State<CelebrationAnimation>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _confettiController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _confettiAnimation;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: widget.reduceMotion
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 800),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: widget.reduceMotion
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 2000),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _confettiAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _confettiController, curve: Curves.easeOut),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    if (widget.reduceMotion) {
      _bounceController.value = 1.0;
      _confettiController.value = 1.0;
      widget.onComplete?.call();
    } else {
      await _bounceController.forward();
      _confettiController.forward();

      // Complete after confetti animation
      Future.delayed(const Duration(milliseconds: 2000), () {
        widget.onComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.message,
      liveRegion: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti background
          if (!widget.reduceMotion)
            AnimatedBuilder(
              animation: _confettiAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(300, 300),
                  painter: ConfettiPainter(progress: _confettiAnimation.value),
                );
              },
            ),

          // Main celebration content
          AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _bounceAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.celebration,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingL),
                    Text(
                      widget.message,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppTheme.spacingM),
                    Text(
                      'Your CloudToLocalLLM is ready to use!',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Custom painter for confetti animation
class ConfettiPainter extends CustomPainter {
  final double progress;

  ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    // Generate confetti pieces
    for (int i = 0; i < 20; i++) {
      final distance = progress * 150;
      final x =
          center.dx + distance * (i % 2 == 0 ? 1 : -1) * (0.5 + (i % 3) * 0.3);
      final y =
          center.dy + distance * (i % 3 == 0 ? 1 : -1) * (0.3 + (i % 4) * 0.2);

      // Vary colors
      final colors = [
        AppTheme.primaryColor,
        AppTheme.secondaryColor,
        AppTheme.successColor,
        AppTheme.warningColor,
      ];
      paint.color = colors[i % colors.length].withValues(
        alpha: (1.0 - progress * 0.5),
      );

      // Draw confetti piece
      canvas.drawCircle(Offset(x, y), 4.0 * (1.0 - progress * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Animated button with hover and press effects
class AnimatedActionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool reduceMotion;
  final String? semanticLabel;

  const AnimatedActionButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.reduceMotion = false,
    this.semanticLabel,
  });

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: widget.reduceMotion
          ? const Duration(milliseconds: 50)
          : const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.reduceMotion) {
      _scaleController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.reduceMotion) {
      _scaleController.reverse();
    }
  }

  void _onTapCancel() {
    if (!widget.reduceMotion) {
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.reduceMotion ? 1.0 : _scaleAnimation.value,
              child: ElevatedButton(
                onPressed: widget.onPressed,
                style: widget.style,
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}
