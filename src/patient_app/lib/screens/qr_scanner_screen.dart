import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/theme.dart';
import '../utils/qr_parser.dart';

/// Full-screen camera scanner for patient pairing QR codes.
///
/// Designed with elder-care accessibility:
/// - Clear, high-contrast viewfinder with corner brackets
/// - Large text instructions (floor 18px)
/// - 88dp minimum touch target buttons
/// - Instant detection feedback
/// - Seamless fallback to manual code entry
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;
  bool _torchActive = false;
  String? _detectedCode;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;

      final parsed = QrParser.parsePairingCode(raw);
      if (parsed != null && parsed.isNotEmpty) {
        setState(() {
          _isProcessing = true;
          _detectedCode = parsed;
        });

        // Pause scanner
        _controller.stop();

        // Provide brief visual confirmation before popping back with the code
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            Navigator.of(context).pop(parsed);
          }
        });
        break;
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) {
        setState(() {
          _torchActive = !_torchActive;
        });
      }
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Camera Viewfinder
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return _buildErrorState(context);
              },
            ),

            // 2. Viewfinder Overlay (Darkened borders + corner brackets)
            _buildScannerOverlay(context),

            // 3. Top Navigation & Controls Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back / Close button with large touch target
                  Material(
                    color: AppColors.ink.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Back',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Action controls (Torch + Camera Flip)
                  Row(
                    children: [
                      Material(
                        color: _torchActive
                            ? AppColors.mugaGold
                            : AppColors.ink.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        child: IconButton(
                          iconSize: 28,
                          tooltip: _torchActive ? 'Turn off flash' : 'Turn on flash',
                          icon: Icon(
                            _torchActive ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _toggleTorch,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: AppColors.ink.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        child: IconButton(
                          iconSize: 28,
                          tooltip: 'Switch camera',
                          icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white),
                          onPressed: _switchCamera,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4. Instructions & Manual Entry Button at Bottom
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Guidance Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _detectedCode != null
                                  ? Icons.check_circle_rounded
                                  : Icons.qr_code_scanner_rounded,
                              color: _detectedCode != null
                                  ? AppColors.sageGreen
                                  : AppColors.terracotta,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _detectedCode != null
                                    ? 'Code Found: $_detectedCode'
                                    : 'Point at caregiver\'s QR code',
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _detectedCode != null
                                      ? AppColors.sageGreen
                                      : AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _detectedCode != null
                              ? 'Connecting your tablet...'
                              : 'Keep the code inside the box to scan automatically.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkSoft,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Prominent 88dp fallback to manual code entry
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size(double.infinity, 88),
                      side: const BorderSide(color: AppColors.border, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.keyboard_outlined,
                          size: 28,
                          color: AppColors.terracotta,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Enter Code Manually',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxSize = (constraints.maxWidth * 0.72).clamp(240.0, 320.0);
          final boxOffset = (constraints.maxHeight - boxSize) / 2 - 40;

          return Stack(
            children: [
              // Target Frame Box
              Positioned(
                top: boxOffset,
                left: (constraints.maxWidth - boxSize) / 2,
                width: boxSize,
                height: boxSize,
                child: CustomPaint(
                  painter: _ScannerFramePainter(
                    borderColor: _detectedCode != null
                        ? AppColors.sageGreen
                        : AppColors.terracotta,
                    isSuccess: _detectedCode != null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: AppColors.terracottaDark,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera Unavailable',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We cannot open the camera. You can still easily enter the pairing code from your caregiver manually.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 88),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_outlined, size: 28, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Enter Code Manually',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter to draw high-contrast corner brackets around the QR target area.
class _ScannerFramePainter extends CustomPainter {
  final Color borderColor;
  final bool isSuccess;

  _ScannerFramePainter({
    required this.borderColor,
    required this.isSuccess,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 36.0;
    const radius = 18.0;

    final path = Path();

    // Top-Left Corner
    path.moveTo(0, cornerLength);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.lineTo(cornerLength, 0);

    // Top-Right Corner
    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, cornerLength);

    // Bottom-Right Corner
    path.moveTo(size.width, size.height - cornerLength);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);
    path.lineTo(size.width - cornerLength, size.height);

    // Bottom-Left Corner
    path.moveTo(cornerLength, size.height);
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.lineTo(0, size.height - cornerLength);

    canvas.drawPath(path, paint);

    // If success, fill subtle translucent tint inside
    if (isSuccess) {
      final fillPaint = Paint()
        ..color = borderColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(radius),
        ),
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) {
    return oldDelegate.borderColor != borderColor || oldDelegate.isSuccess != isSuccess;
  }
}
