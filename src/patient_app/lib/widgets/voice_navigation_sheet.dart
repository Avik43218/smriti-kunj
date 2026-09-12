import 'dart:async';
import 'package:flutter/material.dart';
import '../services/speech_recognition_service.dart';
import '../services/voice_navigation_service.dart';
import '../services/voice_navigation_coordinator.dart';
import '../theme/theme.dart';

/// Modal sheet providing voice navigation interface in English and Bengali.
class VoiceNavigationSheet extends StatefulWidget {
  final VoidCallback? onDismiss;

  const VoiceNavigationSheet({
    super.key,
    this.onDismiss,
  });

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceNavigationSheet(),
    );
  }

  @override
  State<VoiceNavigationSheet> createState() => _VoiceNavigationSheetState();
}

class _VoiceNavigationSheetState extends State<VoiceNavigationSheet>
    with SingleTickerProviderStateMixin {
  final SpeechRecognitionService _speech = SpeechRecognitionService.instance;
  final VoiceNavigationService _voiceNav = VoiceNavigationService.instance;
  final VoiceNavigationCoordinator _coordinator = VoiceNavigationCoordinator.instance;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription<SpeechRecognitionState>? _stateSub;
  StreamSubscription<double>? _rmsSub;
  StreamSubscription<String>? _partialSub;
  StreamSubscription<List<String>>? _resultSub;

  String _selectedLangCode = 'en-US'; // 'en-US' or 'bn-IN'
  String _liveText = '';
  VoiceCommandMatch? _recognizedMatch;
  bool _isExecuting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _subscribeStreams();
    _startListening();
  }

  void _subscribeStreams() {
    _stateSub = _speech.onStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        if (state == SpeechRecognitionState.error) {
          _errorMessage = _speech.lastError ?? 'Recognition error';
        }
      });
    });

    _rmsSub = _speech.onRmsChanged.listen((rms) {
      if (!mounted) return;
      setState(() {});
    });

    _partialSub = _speech.onPartialResult.listen((partial) {
      if (!mounted || _isExecuting) return;
      setState(() {
        _liveText = partial;
        _errorMessage = null;
      });
      // Check partial match for rapid response
      final match = _voiceNav.parseSingle(partial);
      if (match != null && match.confidence >= 0.85) {
        _handleCommandRecognized(match);
      }
    });

    _resultSub = _speech.onResult.listen((results) {
      if (!mounted || _isExecuting) return;
      setState(() {
        _liveText = results.isNotEmpty ? results.first : _liveText;
      });

      final match = _voiceNav.parseCandidates(results);
      if (match != null) {
        _handleCommandRecognized(match);
      } else if (results.isNotEmpty) {
        setState(() {
          _errorMessage = _isBengali
              ? 'শব্দটি বুঝতে পারিনি। অনুগ্রহ করে তালিকার কোনো একটি কমান্ড বলুন।'
              : 'Could not recognize command. Please say one of the options below.';
        });
      }
    });
  }

  bool get _isBengali => _selectedLangCode.startsWith('bn');

  Future<void> _startListening() async {
    setState(() {
      _errorMessage = null;
      _recognizedMatch = null;
      _liveText = '';
    });

    final hasPerm = await _speech.hasPermission();
    if (!hasPerm) {
      final granted = await _speech.requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() {
            _errorMessage = _isBengali
                ? 'মাইক্রোফোন অনুমতি প্রয়োজন'
                : 'Microphone permission required';
          });
        }
        return;
      }
    }

    await _speech.startListening(language: _selectedLangCode);
  }

  Future<void> _toggleLanguage() async {
    await _speech.stopListening();
    setState(() {
      _selectedLangCode = _isBengali ? 'en-US' : 'bn-IN';
      _liveText = '';
      _errorMessage = null;
    });
    await _startListening();
  }

  void _handleCommandRecognized(VoiceCommandMatch match) {
    if (_isExecuting) return;
    setState(() {
      _isExecuting = true;
      _recognizedMatch = match;
    });

    // Provide visual confirmation feedback before navigating
    Future.delayed(const Duration(milliseconds: 650), () async {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close sheet
      await _coordinator.execute(match.command, context);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _rmsSub?.cancel();
    _partialSub?.cancel();
    _resultSub?.cancel();
    _speech.stopListening();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = _speech.state == SpeechRecognitionState.listening ||
        _speech.state == SpeechRecognitionState.ready;
    final rmsScale = 1.0 + (_speech.rmsDb.clamp(0.0, 15.0) / 15.0) * 0.35;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Top Header: Title + Language Switcher + Close Button
            Row(
              children: [
                const Icon(Icons.mic_rounded, color: AppColors.terracotta, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isBengali ? 'কণ্ঠস্বৰ নির্দেশিকা' : 'Voice Navigation',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        _isBengali
                            ? 'বলুন: বাড়ি, খেলা, অনুস্মারক, গ্যালারি, সিংক, সাহায্য, ভাষা...'
                            : 'Say: Home, Games, Reminders, Gallery, Sync, Help, Languages...',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                // Language Toggle Pill
                GestureDetector(
                  onTap: _toggleLanguage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.language_rounded,
                          size: 18,
                          color: _isBengali ? AppColors.terracotta : AppColors.inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isBengali ? 'বাংলা' : 'EN',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isBengali ? AppColors.terracotta : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 28, color: AppColors.inkSoft),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pulsing Mic Visualizer
            Center(
              child: GestureDetector(
                onTap: _startListening,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Ripple
                    if (isListening)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value * rmsScale,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.terracotta.withValues(alpha: 0.18),
                              ),
                            ),
                          );
                        },
                      ),
                    // Inner Circle
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: _recognizedMatch != null
                            ? AppColors.sageGreen
                            : (isListening ? AppColors.terracotta : AppColors.inkSoft),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_recognizedMatch != null
                                    ? AppColors.sageGreen
                                    : AppColors.terracotta)
                                .withValues(alpha: 0.4),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _recognizedMatch != null
                            ? Icons.check_rounded
                            : (isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Live Transcription / Status message
            Center(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _recognizedMatch != null
                        ? AppColors.sageGreen
                        : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: _recognizedMatch != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.sageGreen, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _isBengali
                                ? 'খুলছে: ${_recognizedMatch!.command.bengaliTitle}...'
                                : 'Opening: ${_recognizedMatch!.command.englishTitle}...',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _liveText.isNotEmpty
                            ? '"$_liveText"'
                            : (isListening
                                ? (_isBengali ? 'কথা শুনছি...' : 'Listening...')
                                : (_isBengali
                                    ? 'বলতে মাইকে চাপ দিন'
                                    : 'Tap microphone to speak')),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _liveText.isNotEmpty
                              ? AppColors.ink
                              : AppColors.inkSoft,
                        ),
                      ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Command Cheat-Sheet Cards (Tap any command as fallback accessibility)
            Text(
              _isBengali ? 'সমর্থিত ভয়েস নির্দেশাবলী:' : 'Supported Voice Commands:',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: VoiceCommand.values.map((cmd) {
                    return _VoiceCommandBadge(
                      command: cmd,
                      isBengali: _isBengali,
                      isSelected: _recognizedMatch?.command == cmd,
                      onTap: () => _handleCommandRecognized(VoiceCommandMatch(
                        command: cmd,
                        matchedCandidate: cmd.englishTitle,
                        confidence: 1.0,
                        isBengali: _isBengali,
                      )),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _VoiceCommandBadge extends StatelessWidget {
  final VoiceCommand command;
  final bool isBengali;
  final bool isSelected;
  final VoidCallback onTap;

  const _VoiceCommandBadge({
    required this.command,
    required this.isBengali,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? command.color.withValues(alpha: 0.18)
              : AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? command.color : AppColors.border,
            width: isSelected ? 2.0 : 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(command.icon, size: 20, color: command.color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isBengali ? command.bengaliTitle : command.englishTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? command.color : AppColors.ink,
                  ),
                ),
                Text(
                  isBengali ? command.englishTitle : command.bengaliTitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
