import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/session_service.dart';
import '../theme/theme.dart';
import '../widgets/app_background.dart';
import 'home_screen.dart';
import 'qr_scanner_screen.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _openQrScanner() async {
    setState(() {
      _errorMessage = null;
    });

    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );

    if (!mounted || scannedCode == null || scannedCode.trim().isEmpty) return;

    await _pairWithCode(scannedCode);
  }

  Future<void> _handleConfirm() async {
    final code = _codeController.text.trim();
    await _pairWithCode(code);
  }

  Future<void> _pairWithCode(String code) async {
    final cleanCode = code.trim();

    if (cleanCode.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the pairing code from your caregiver.';
      });
      return;
    }

    if (cleanCode.length < 4) {
      setState(() {
        _errorMessage = 'Please check the code and try again.';
      });
      return;
    }

    // Populate controller so user sees which code was scanned/submitted
    if (_codeController.text != cleanCode) {
      _codeController.text = cleanCode;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final success = await SessionService.instance.pairDevice(cleanCode);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = SessionService.instance.errorMessage ??
              'Unable to connect with this code. Please check with your caregiver and try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final clean = e.toString().replaceAll('Exception: ', '').trim();
        _errorMessage = clean.isNotEmpty ? clean : 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand logo — first thing a new user sees
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 96,
                    height: 96,
                    semanticsLabel: 'Smriti Kunj logo',
                  ),
                  const SizedBox(height: 20),

                  // App Title & Calm Greeting
                  Text(
                    'Smriti Kunj',
                    textAlign: TextAlign.center,
                    style: textTheme.displayLarge?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Connect with Caregiver',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Scan the caregiver QR code or enter your 6-digit code below.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.inkSoft,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // PRIMARY OPTION: Instant QR Scanner Button (88dp touch target)
                  ElevatedButton(
                    key: const Key('scan_qr_button'),
                    onPressed: _isLoading ? null : _openQrScanner,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 88),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 3,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Scan QR Code',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Calming, accessible separator
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.border, thickness: 1.5)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'OR ENTER MANUALLY',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.border, thickness: 1.5)),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Surface Card containing the manual input field and inline error
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Pairing Code',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Single input field
                        TextField(
                          key: const Key('pairing_code_textfield'),
                          controller: _codeController,
                          focusNode: _focusNode,
                          autofocus: false,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4.0,
                            color: AppColors.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. 123456',
                            hintStyle: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 2.0,
                              color: AppColors.inkSoft.withValues(alpha: 0.6),
                            ),
                            filled: true,
                            fillColor: AppColors.cream,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.terracotta,
                                width: 2.0,
                              ),
                            ),
                          ),
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() {
                                _errorMessage = null;
                              });
                            }
                          },
                          onSubmitted: (_) => _handleConfirm(),
                        ),

                        // Inline Error Display (Using terracottaDark — alertRed reserved for SOS only)
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.terracottaDark,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.terracottaDark,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Manual Confirm Button (88dp min height, icon + word label)
                  ElevatedButton(
                    key: const Key('manual_confirm_button'),
                    onPressed: _isLoading ? null : _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 88),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 28,
                            width: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 28,
                                color: Colors.white,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
