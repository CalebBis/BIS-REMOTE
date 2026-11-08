import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/remote_key.dart';
import '../models/tv_capability.dart';
import '../services/tv_controller.dart';

/// Widget de pavé tactile (Touchpad) ergonomique de 240 dp de haut.
/// Prend en charge le déplacement avec throttle (90 ms), le clic par tap,
/// le défilement à deux doigts, et un mode de secours par flèches si le pointeur
/// n'est pas supporté par la TV.
class TouchpadWidget extends ConsumerStatefulWidget {
  const TouchpadWidget({super.key});

  @override
  ConsumerState<TouchpadWidget> createState() => _TouchpadWidgetState();
}

class _TouchpadWidgetState extends ConsumerState<TouchpadWidget>
    with SingleTickerProviderStateMixin {
  Offset? _touchPos;
  Offset? _ripplePos;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  DateTime? _downTime;
  double _totalMovement = 0.0;
  double _fallbackDx = 0.0;
  double _fallbackDy = 0.0;

  double _accumulatedDx = 0.0;
  double _accumulatedDy = 0.0;
  DateTime _lastMoveSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _rippleAnimation = CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    );
    _rippleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _ripplePos = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  void _triggerRipple(Offset pos) {
    setState(() {
      _ripplePos = pos;
    });
    _rippleController.forward(from: 0.0);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    setState(() {
      _touchPos = details.localFocalPoint;
    });
    _downTime = DateTime.now();
    _totalMovement = 0.0;
    _fallbackDx = 0.0;
    _fallbackDy = 0.0;
    _accumulatedDx = 0.0;
    _accumulatedDy = 0.0;
  }

  void _handleScaleUpdate(
    ScaleUpdateDetails details,
    TvController controller,
    bool hasPointer,
  ) {
    setState(() {
      _touchPos = details.localFocalPoint;
    });

    final delta = details.focalPointDelta;
    _totalMovement += delta.distance;

    if (hasPointer) {
      if (details.pointerCount >= 2) {
        // Défilement à deux doigts
        controller.sendScroll(delta.dy);
      } else {
        // Déplacement du pointeur à un doigt avec throttle (~90 ms)
        _accumulatedDx += delta.dx;
        _accumulatedDy += delta.dy;

        final now = DateTime.now();
        if (now.difference(_lastMoveSent).inMilliseconds >= 90) {
          if (_accumulatedDx != 0 || _accumulatedDy != 0) {
            controller.sendPointerMove(_accumulatedDx, _accumulatedDy);
            _accumulatedDx = 0.0;
            _accumulatedDy = 0.0;
            _lastMoveSent = now;
          }
        }
      }
    } else {
      // Mode de secours : accumulation pour détecter un swipe directionnel
      _fallbackDx += delta.dx;
      _fallbackDy += delta.dy;

      const swipeStep = 45.0;
      if (_fallbackDx.abs() >= swipeStep || _fallbackDy.abs() >= swipeStep) {
        HapticFeedback.lightImpact();
        if (_fallbackDx.abs() > _fallbackDy.abs()) {
          controller.sendCommand(
            _fallbackDx > 0 ? RemoteKey.right : RemoteKey.left,
          );
        } else {
          controller.sendCommand(
            _fallbackDy > 0 ? RemoteKey.down : RemoteKey.up,
          );
        }
        _fallbackDx = 0.0;
        _fallbackDy = 0.0;
      }
    }
  }

  void _handleScaleEnd(
    ScaleEndDetails details,
    TvController controller,
    bool hasPointer,
  ) {
    final pos = _touchPos;
    setState(() {
      _touchPos = null;
    });

    final now = DateTime.now();
    final duration = _downTime != null
        ? now.difference(_downTime!).inMilliseconds
        : 999;

    // Détection d'un tap simple (< 300 ms et pas de mouvement significatif)
    if (duration < 300 && _totalMovement < 8.0 && pos != null) {
      HapticFeedback.lightImpact();
      _triggerRipple(pos);

      if (hasPointer) {
        controller.sendPointerClick();
      } else {
        controller.sendCommand(RemoteKey.ok);
      }
    } else if (hasPointer && (_accumulatedDx != 0 || _accumulatedDy != 0)) {
      // Envoi du reste des déplacements accumulés
      controller.sendPointerMove(_accumulatedDx, _accumulatedDy);
      _accumulatedDx = 0.0;
      _accumulatedDy = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(tvControllerProvider);
    final hasPointer = controller.capabilities.contains(TvCapability.pointer);

    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2628),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0x6600C8F0),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: (d) => _handleScaleUpdate(d, controller, hasPointer),
        onScaleEnd: (d) => _handleScaleEnd(d, controller, hasPointer),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Textes informatifs discrets au centre
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasPointer ? Icons.touch_app_outlined : Icons.swap_calls_rounded,
                    color: const Color(0xFF7FD6DC).withAlpha(180),
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasPointer
                        ? 'Glissez pour déplacer le curseur'
                        : 'Curseur non supporté par cette TV : mode flèches',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFE3E8E8).withAlpha(220),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasPointer
                        ? 'Touchez pour cliquer · deux doigts pour défiler'
                        : 'Glissez pour naviguer · touchez pour OK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFE3E8E8).withAlpha(140),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Onde visuelle (Ripple) lors d'un tap
            if (_ripplePos != null)
              AnimatedBuilder(
                animation: _rippleAnimation,
                builder: (context, child) {
                  final radius = 12.0 + (_rippleAnimation.value * 40.0);
                  final opacity = (1.0 - _rippleAnimation.value).clamp(0.0, 1.0);
                  return Positioned(
                    left: _ripplePos!.dx - radius,
                    top: _ripplePos!.dy - radius,
                    child: IgnorePointer(
                      child: Container(
                        width: radius * 2,
                        height: radius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00C8F0).withValues(alpha: opacity * 0.35),
                          border: Border.all(
                            color: const Color(0xFF00C8F0).withValues(alpha: opacity * 0.7),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Cercle cyan translucide sous le doigt pendant le toucher
            if (_touchPos != null)
              Positioned(
                left: _touchPos!.dx - 22,
                top: _touchPos!.dy - 22,
                child: IgnorePointer(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00C8F0).withAlpha(75),
                      border: Border.all(
                        color: const Color(0xFF00C8F0).withAlpha(180),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
