import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Wraps screen content with a translucent regional scenery background
/// layered over the solid [AppColors.cream] brand base.
///
/// - Base layer: Solid [AppColors.cream]
/// - Scenery layer: Low-opacity (default [kSceneryOpacity] = 0.20) WebP image
/// - Subtle edge scrim: Vertical gradient overlay softly blending into cream
/// - Accessibility: Automatically suppresses scenery if [MediaQuery.highContrastOf]
///   is active to preserve contrast for visual impairments.
/// - Semantics: Scenery layer is wrapped in [ExcludeSemantics] so screen readers
///   never encounter decorative scenery assets.
/// - Performance: Wrapped in [RepaintBoundary] to isolate repaints from dynamic child UI.
class AppBackground extends StatefulWidget {
  final Widget child;
  final double? opacity;
  final bool enabled;
  final Alignment imageAlignment;

  const AppBackground({
    super.key,
    required this.child,
    this.opacity,
    this.enabled = true,
    this.imageAlignment = const Alignment(0.0, -0.3),
  });

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.enabled && !MediaQuery.highContrastOf(context)) {
      precacheImage(const AssetImage(kSceneryAssetPath), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isHighContrast = MediaQuery.highContrastOf(context);
    final bool shouldShowScenery = widget.enabled && !isHighContrast;
    final double effectiveOpacity =
        (widget.opacity ?? kSceneryOpacity).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Solid brand cream base
        const ColoredBox(color: AppColors.cream),

        // 2. Translucent scenery layer + subtle gradient scrim
        if (shouldShowScenery)
          RepaintBoundary(
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: effectiveOpacity,
                    child: Image.asset(
                      kSceneryAssetPath,
                      fit: BoxFit.cover,
                      alignment: widget.imageAlignment,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox.expand();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 3. Foreground content
        widget.child,
      ],
    );
  }
}
