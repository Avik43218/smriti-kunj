import 'dart:math';

/// Reusable warm, non-judgmental, effort-based completion messages for mini-games.
class CompletionMessage {
  final String headingEn;
  final String headingAs;
  final String subheadingEn;
  final String subheadingAs;

  const CompletionMessage({
    required this.headingEn,
    required this.headingAs,
    required this.subheadingEn,
    required this.subheadingAs,
  });

  String heading(String languageCode) =>
      languageCode == 'as' ? headingAs : headingEn;

  String subheading(String languageCode) =>
      languageCode == 'as' ? subheadingAs : subheadingEn;

  static const List<CompletionMessage> variants = [
    CompletionMessage(
      headingEn: "Great job today!",
      headingAs: "আজি বহুত ভাল কৰিলে!",
      subheadingEn: "You finished the game!",
      subheadingAs: "আপুনি খেলখন সম্পূৰ্ণ কৰিলে!",
    ),
    CompletionMessage(
      headingEn: "Wonderful effort!",
      headingAs: "সুন্দৰ প্ৰচেষ্টা!",
      subheadingEn: "Thank you for taking time to play today.",
      subheadingAs: "আজি খেলখন খেলাৰ বাবে ধন্যবাদ।",
    ),
    CompletionMessage(
      headingEn: "Well done!",
      headingAs: "খুব ভাল লাগিল!",
      subheadingEn: "Every session keeps your mind sharp and active.",
      subheadingAs: "প্ৰতিটো অভ্যাসে মন সক্ৰিয় আৰু সুস্থ কৰি ৰাখে।",
    ),
    CompletionMessage(
      headingEn: "Fantastic work!",
      headingAs: "চমৎকাৰ কাম!",
      subheadingEn: "You gave it your best focus and attention.",
      subheadingAs: "আপুনি সম্পূৰ্ণ মনোযোগেৰে খেলখন খেলিলে।",
    ),
    CompletionMessage(
      headingEn: "Proud of your effort!",
      headingAs: "আপোনাৰ প্ৰচেষ্টাক লৈ গৌৰৱান্বিত!",
      subheadingEn: "You did wonderfully today!",
      subheadingAs: "আজি আপুনি অতি সুন্দৰকৈ কৰিলে!",
    ),
  ];

  static CompletionMessage getRandom([Random? random]) {
    final r = random ?? Random();
    return variants[r.nextInt(variants.length)];
  }
}
