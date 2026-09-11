import 'package:flutter/material.dart';
import 'package:patient_app/services/tts_service.dart';

class TapTargetGameScreen extends StatefulWidget {
  final String langCode; // 'en', 'as', or 'bn'

  const TapTargetGameScreen({
    super.key,
    this.langCode = 'en',
  });

  @override
  State<TapTargetGameScreen> createState() => _TapTargetGameScreenState();
}

class _TapTargetGameScreenState extends State<TapTargetGameScreen> {
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    _initAndAnnounce();
  }

  Future<void> _initAndAnnounce() async {
    await _tts.initTts();
    _announceInstructions();
  }

  void _announceInstructions() async {
    String intro;
    if (widget.langCode == 'as') {
      intro = "পৰ্দাত দেখা পোৱা লক্ষ্যটোত স্পৰ্শ কৰক।";
    } else if (widget.langCode == 'bn') {
      intro = "পর্দায় প্রদর্শিত লক্ষ্যটি স্পর্শ করুন।";
    } else {
      intro = "Tap on the highlighted target as fast as you can.";
    }

    await _tts.speak(intro, languageCode: widget.langCode);
  }

  void _onTargetHit() {
    String message;
    if (widget.langCode == 'as') {
      message = "সুন্দৰ শট!";
    } else if (widget.langCode == 'bn') {
      message = "খুব ভালো!";
    } else {
      message = "Good hit!";
    }

    _tts.speak(message, languageCode: widget.langCode);
  }

  void _onGameComplete(int score) {
    String message;
    if (widget.langCode == 'as') {
      message = "ধন্যবাদ! আপোনাৰ স্কোৰ হ'ল $score।";
    } else if (widget.langCode == 'bn') {
      message = "ধন্যবাদ! আপনার স্কোর হলো $score।";
    } else {
      message = "Game over! Your final score is $score.";
    }

    _tts.speak(message, languageCode: widget.langCode);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.langCode == 'as'
              ? 'লক্ষ্য স্পৰ্শ'
              : (widget.langCode == 'bn' ? 'টার্গেট ট্যাপ' : 'Tap Target'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: _announceInstructions,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _onTargetHit,
              child: const Text("Simulate Target Hit"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _onGameComplete(120),
              child: const Text("Simulate Game Complete"),
            ),
          ],
        ),
      ),
    );
  }
}