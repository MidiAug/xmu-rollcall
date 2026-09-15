import 'package:flutter/material.dart';

/// Diagonal corner ribbon (HOT-style). Parent must [Clip] (e.g. [Panel]).
class CornerRibbon extends StatelessWidget {
  const CornerRibbon({
    super.key,
    required this.label,
    this.color = const Color(0xFFE11D48),
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: SizedBox(
        width: 64,
        height: 64,
        child: ClipRect(
          child: Align(
            alignment: Alignment.topRight,
            child: Transform.translate(
              offset: const Offset(18, -18),
              child: Transform.rotate(
                angle: 0.785398, // 45°
                child: Container(
                  width: 84,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color,
                        Color.lerp(color, Colors.black, 0.12)!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
