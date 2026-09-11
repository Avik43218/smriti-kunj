import 'dart:math';

/// Reusable warm, non-judgmental, effort-based completion messages for mini-games.
class CompletionMessage {
  final String headingEn;
  final String headingAs;
  final String headingBn;
  final String headingBrx;
  final String subheadingEn;
  final String subheadingAs;
  final String subheadingBn;
  final String subheadingBrx;

  const CompletionMessage({
    required this.headingEn,
    required this.headingAs,
    required this.headingBn,
    required this.headingBrx,
    required this.subheadingEn,
    required this.subheadingAs,
    required this.subheadingBn,
    required this.subheadingBrx,
  });

  String heading(String languageCode) {
    switch (languageCode) {
      case 'as':
        return headingAs;
      case 'bn':
        return headingBn;
      case 'brx':
        return headingBrx;
      default:
        return headingEn;
    }
  }

  String subheading(String languageCode) {
    switch (languageCode) {
      case 'as':
        return subheadingAs;
      case 'bn':
        return subheadingBn;
      case 'brx':
        return subheadingBrx;
      default:
        return subheadingEn;
    }
  }

  static const List<CompletionMessage> variants = [
    CompletionMessage(
      headingEn: "Great job today!",
      headingAs: "আজি বহুত ভাল কৰিলে!",
      headingBn: "আজকে দারুণ করেছ!",
      headingBrx: "आजो लानाय मोनसे गोग्लैयो!",
      subheadingEn: "You finished the game!",
      subheadingAs: "আপুনি খেলখন সম্পূৰ্ণ কৰিলে!",
      subheadingBn: "তুমি খেলাটা শেষ করেছ!",
      subheadingBrx: "नोंनि खेल सोरजिनो जादों!",
    ),
    CompletionMessage(
      headingEn: "Wonderful effort!",
      headingAs: "সুন্দৰ প্ৰচেষ্টা!",
      headingBn: "অসাধারণ চেষ্টা!",
      headingBrx: "सुन्दर खामानि!",
      subheadingEn: "Thank you for taking time to play today.",
      subheadingAs: "আজি খেলখন খেলাৰ বাবে ধন্যবাদ।",
      subheadingBn: "আজকে খেলার জন্য ধন্যবাদ।",
      subheadingBrx: "आजो खेलाव समाव थानाय खातिर दाबोदो।",
    ),
    CompletionMessage(
      headingEn: "Well done!",
      headingAs: "খুব ভাল লাগিল!",
      headingBn: "খুব ভালো হয়েছে!",
      headingBrx: "नोंनो लानाय गोनांथि!",
      subheadingEn: "Every session keeps your mind sharp and active.",
      subheadingAs: "প্ৰতিটো অভ্যাসে মন সক্ৰিয় আৰু সুস্থ কৰি ৰাখে।",
      subheadingBn: "প্রতিটি সেশন তোমার মনকে সতেজ ও সক্রিয় রাখে।",
      subheadingBrx: "मोनसे-मोनसे खेलाव नोंनि मन हांखो आरो बिसागारि दं।",
    ),
    CompletionMessage(
      headingEn: "Fantastic work!",
      headingAs: "চমৎকাৰ কাম!",
      headingBn: "অসাধারণ কাজ!",
      headingBrx: "गोनां लानाय खामानि!",
      subheadingEn: "You gave it your best focus and attention.",
      subheadingAs: "আপুনি সম্পূৰ্ণ মনোযোগেৰে খেলখন খেলিলে।",
      subheadingBn: "তুমি পূর্ণ মনোযোগ দিয়ে খেলেছ।",
      subheadingBrx: "नों सानफ्रोमनि मनोयोग दिनो खेलायो।",
    ),
    CompletionMessage(
      headingEn: "Proud of your effort!",
      headingAs: "আপোনাৰ প্ৰচেষ্টাক লৈ গৌৰৱান্বিত!",
      headingBn: "তোমার চেষ্টায় আমরা গর্বিত!",
      headingBrx: "नोंनि खामानियाव गोरोन्थि!",
      subheadingEn: "You did wonderfully today!",
      subheadingAs: "আজি আপুনি অতি সুন্দৰকৈ কৰিলে!",
      subheadingBn: "আজকে তুমি দারুণভাবে করেছ!",
      subheadingBrx: "आजो नोंनो मोजां लानायो!",
    ),
    CompletionMessage(
      headingEn: "Keep it up!",
      headingAs: "এনেকুৱাই কৰি থাকক!",
      headingBn: "এভাবেই চালিয়ে যাও!",
      headingBrx: "जाहोनाय थाखो थानो!",
      subheadingEn: "Your dedication makes a difference.",
      subheadingAs: "আপোনাৰ চেষ্টাই পাৰ্থক্য আনে।",
      subheadingBn: "তোমার পরিশ্রম পার্থক্য তৈরি করে।",
      subheadingBrx: "नोंनि खामानियाव फारि जादों।",
    ),
  ];

  static CompletionMessage getRandom([Random? random]) {
    final r = random ?? Random();
    return variants[r.nextInt(variants.length)];
  }
}
