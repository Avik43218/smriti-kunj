import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/theme.dart';
import '../models/market_item.dart';

/// Abstract prompt delivery contract for Market Trip game.
abstract class PromptDeliveryService {
  Widget buildPromptView({
    required BuildContext context,
    required List<MarketItem> items,
    required String languageCode,
    required VoidCallback onPromptFinished,
  });
}

/// Text-based implementation of PromptDeliveryService.
/// Shows prompt item list as large dementia-safe cards with fixed read-time.
class TextPromptDelivery implements PromptDeliveryService {
  final int secondsPerItem;

  const TextPromptDelivery({this.secondsPerItem = 4});

  @override
  Widget buildPromptView({
    required BuildContext context,
    required List<MarketItem> items,
    required String languageCode,
    required VoidCallback onPromptFinished,
  }) {
    return _TextPromptWidget(
      items: items,
      languageCode: languageCode,
      secondsPerItem: secondsPerItem,
      onPromptFinished: onPromptFinished,
    );
  }
}

class _TextPromptWidget extends StatefulWidget {
  final List<MarketItem> items;
  final String languageCode;
  final int secondsPerItem;
  final VoidCallback onPromptFinished;

  const _TextPromptWidget({
    required this.items,
    required this.languageCode,
    required this.secondsPerItem,
    required this.onPromptFinished,
  });

  @override
  State<_TextPromptWidget> createState() => _TextPromptWidgetState();
}

class _TextPromptWidgetState extends State<_TextPromptWidget> {
  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = (widget.items.length * widget.secondsPerItem).clamp(8, 30);
    _remainingSeconds = _totalSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    widget.onPromptFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _promptTitle {
    if (widget.languageCode == 'as') {
      return 'আজি আমি কি কি কিনিব লাগে মনত ৰাখক:';
    }
    return 'Today we need to buy these items:';
  }

  String get _buttonText {
    if (widget.languageCode == 'as') {
      return 'মই মনত ৰাখিলোঁ';
    }
    return "I'm Ready to Shop";
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 0.0;

    return Container(
      color: AppColors.cream,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruction Title (18px+ text)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_cart,
                  color: AppColors.terracotta,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _promptTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Read Timer Progress Indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.mugaGold),
            ),
          ),
          const SizedBox(height: 20),

          // Prompt Cards List (Scrollable if needed)
          Expanded(
            child: ListView.separated(
              itemCount: widget.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final itemName = item.getName(widget.languageCode);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.terracotta, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Item Number Badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.terracotta,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Visual Icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          item.iconData,
                          size: 32,
                          color: AppColors.terracottaDark,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Item Name (20px+ font)
                      Expanded(
                        child: Text(
                          itemName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Primary Ready Action Button (Min target 88dp height, 20px text floor)
          ElevatedButton(
            onPressed: _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 3,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 32),
                const SizedBox(width: 12),
                Text(
                  _buttonText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
