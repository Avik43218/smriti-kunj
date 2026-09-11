import 'package:flutter/material.dart';
import 'package:patient_app/services/tts_service.dart';

class PairMatchingGameScreen extends StatefulWidget {
  final String langCode; // 'en', 'as', or 'bn'

  const PairMatchingGameScreen({
    super.key,
    this.langCode = 'en',
  });

  @override
  State<PairMatchingGameScreen> createState() => _PairMatchingGameScreenState();
}

class _PairMatchingGameScreenState extends State<PairMatchingGameScreen> {
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
      intro = "একে ছবিৰ জোৰাবোৰ বিচাৰি উলিয়াওক।";
    } else if (widget.langCode == 'bn') {
      intro = "একই ছবির জোড়াগুলো খুঁজে বের করুন।";
    } else {
      intro = "Match the identical pairs of cards.";
    }

    await _tts.speak(intro, languageCode: widget.langCode);
  }

  void _onPairMatched() {
    String message;
    if (widget.langCode == 'as') {
      message = "সুন্দৰ! মিল পাইছে।";
    } else if (widget.langCode == 'bn') {
      message = "চমৎকার! জোড়া মিলেছে।";
    } else {
      message = "Great job! That's a match.";
    }

    _tts.speak(message, languageCode: widget.langCode);
  }

  void _onGameComplete() {
    String message;
    if (widget.langCode == 'as') {
      message = "ধন্যবাদ! খেলখন সম্পূৰ্ণ হ'ল।";
    } else if (widget.langCode == 'bn') {
      message = "ধন্যবাদ! খেলাটি সম্পন্ন হয়েছে।";
    } else {
      message = "Congratulations! You matched all pairs.";
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
              ? 'যোৰ মিলোৱা'
              : (widget.langCode == 'bn' ? 'জোড়া মিলান' : 'Pair Matching'),
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
              onPressed: _onPairMatched,
              child: const Text("Simulate Pair Matched"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _onGameComplete,
              child: const Text("Simulate Game Complete"),
            ),
          ],
        ),
      ),
    );
  }
}