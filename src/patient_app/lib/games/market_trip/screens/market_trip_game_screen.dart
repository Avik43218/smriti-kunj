import 'package:flutter/material.dart';
import 'package:patient_app/services/tts_service.dart';

class MarketTripGameScreen extends StatefulWidget {
  final List<String> shoppingList;
  final String langCode; // 'en', 'as', or 'bn'

  const MarketTripGameScreen({
    super.key,
    required this.shoppingList,
    this.langCode = 'en',
  });

  @override
  State<MarketTripGameScreen> createState() => _MarketTripGameScreenState();
}

class _MarketTripGameScreenState extends State<MarketTripGameScreen> {
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    _initAndAnnounce();
  }

  Future<void> _initAndAnnounce() async {
    await _tts.initTts();
    _announceShoppingList();
  }

  void _announceShoppingList() async {
    String intro;
    if (widget.langCode == 'as') {
      intro = "আজি আমি কি কি কিনিব লাগিব মনত ৰাখক:";
    } else if (widget.langCode == 'bn') {
      intro = "আজ আমাদের কি কি কিনতে হবে মনে রাখুন:";
    } else {
      intro = "Today we need to buy these items:";
    }

    String itemsText = widget.shoppingList.join(", ");
    await _tts.speak("$intro $itemsText", languageCode: widget.langCode);
  }

  void _onDistractorStart() {
    String prompt;
    if (widget.langCode == 'as') {
      prompt = "অলপ সময় জিৰণি লওক: ছা গছত পানী দিয়ক";
    } else if (widget.langCode == 'bn') {
      prompt = "কিছুক্ষণ বিশ্রাম নিন: চা গাছে জল দিন";
    } else {
      prompt = "Take a short breath: Water the tea leaves";
    }

    _tts.speak(prompt, languageCode: widget.langCode);
  }

  void _onRecallPhaseStart() {
    String prompt;
    if (widget.langCode == 'as') {
      prompt = "বজাৰৰ মোনাত কি কি আছিল বাছনি কৰক";
    } else if (widget.langCode == 'bn') {
      prompt = "বাজারের থলিতে কি কি ছিল তা নির্বাচন করুন";
    } else {
      prompt = "Select the items that were on your shopping list";
    }

    _tts.speak(prompt, languageCode: widget.langCode);
  }

  void _onGameComplete(int scorePercentage) {
    String prompt;
    if (widget.langCode == 'as') {
      prompt = "ধন্যবাদ! বজাৰৰ যাত্ৰা সম্পূৰ্ণ হ'ল।";
    } else if (widget.langCode == 'bn') {
      prompt = "ধন্যবাদ! বাজারের যাত্রা সম্পন্ন হলো।";
    } else {
      prompt = "Well done! Market Trip complete. Your recall accuracy is $scorePercentage percent.";
    }

    _tts.speak(prompt, languageCode: widget.langCode);
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
              ? 'বজাৰৰ যাত্রা'
              : (widget.langCode == 'bn' ? 'বাজারের যাত্রা' : 'The Market Trip'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: _announceShoppingList,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _onDistractorStart,
              child: const Text("Start Distractor Task"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _onRecallPhaseStart,
              child: const Text("Start Recall Phase"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _onGameComplete(85),
              child: const Text("Complete Game"),
            ),
          ],
        ),
      ),
    );
  }
}