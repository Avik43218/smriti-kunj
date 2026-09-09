import 'locale_service.dart';

/// All UI strings for the patient app, keyed by [AppLang].
/// Usage: final s = AppStrings(context.watch<LocaleService>().lang);
class AppStrings {
  final AppLang lang;
  const AppStrings(this.lang);

  bool get _as => lang == AppLang.assamese;

  // ── App-wide ──────────────────────────────────────────────────────────────
  String get appName       => _as ? 'স্মৃতি কুঞ্জ'           : 'Smriti Kunj';
  String get todayActivity => _as ? 'আজিৰ কাৰ্যসূচী'         : "Today's Activities";

  // ── Home screen tiles ─────────────────────────────────────────────────────
  String get brainGames          => _as ? 'মগজুৰ খেল'                    : 'Brain Games';
  String get brainGamesSubtitle  => _as ? 'মিলান আৰু স্মৃতিৰ খেল খেলক'  : 'Play matching & memory games';
  String get reminders           => _as ? 'দৈনিক স্মাৰণ'                 : 'Daily Reminders';
  String get remindersSubtitle   => _as ? 'দৰব, পানী আৰু ৰুটিন'          : 'Medicines, hydration & routine';
  String get memoryGallery       => _as ? 'স্মৃতিৰ গেলেৰী'               : 'Memory Gallery';
  String get memoryGallerySubtitle => _as ? 'পৰিয়ালৰ ফটো আৰু কণ্ঠস্বৰ' : 'Family photos & voice notes';

  // ── Games screen ──────────────────────────────────────────────────────────
  String get marketTripTitle    => _as ? 'বজাৰৰ যাত্ৰা'              : 'The Market Trip';
  String get marketTripSubtitle => _as ? 'কিনা-বেচাৰ তালিকা মনত ৰাখক' : 'Remember the shopping list';
  String get workingMemory      => _as ? 'কাৰ্যস্মৃতি'               : 'Working Memory';
  String get chooseDifficulty   => _as ? 'কঠিনতা বাছনি কৰক:'         : 'Choose difficulty:';
  String get easy               => _as ? 'সহজ'                        : 'Easy';
  String get medium             => _as ? 'মধ্যম'                     : 'Medium';
  String get hard               => _as ? 'কঠিন'                      : 'Hard';
  String get easyItems          => _as ? '২ টা বস্তু'                 : '2 items';
  String get mediumItems        => _as ? '৩ টা বস্তু'                 : '3 items';
  String get hardItems          => _as ? '৬ টা বস্তু'                 : '6 items';
  String get playNow            => _as ? 'এতিয়া খেলক'               : 'Play Now';
  String get comingSoon         => _as ? 'সোনকালে আহিব'              : 'Coming soon';

  String get easyPairs          => _as ? "৪ যোৰ"                     : "4 pairs";
  String get mediumPairs        => _as ? "৬ যোৰ"                     : "6 pairs";
  String get hardPairs          => _as ? "৮ যোৰ"                     : "8 pairs";

  // ── Coming-soon game titles / subtitles ───────────────────────────────────
  String get pairMatchTitle     => _as ? "যোৰ মিলোৱা"                           : "Pair Matching";
  String get pairMatchSubtitle  => _as ? "মিলন যোৰ বিচাৰিবলৈ কাৰ্ড ওলোটাওক"   : "Flip cards to find matching pairs";
  String get episodicMemory     => _as ? "ঘটনাৰ স্মৃতি"                         : "Episodic Memory";
  String get familyFinderTitle  => _as ? "পৰিয়াল আৰু গাঁৱৰ বস্তু"             : "Family & Village Finder";
  String get familyFinderSub    => _as ? "পৰিয়ালৰ সদস্য আৰু বস্তু চিনি পাওক" : "Recognise family members & objects";
  String get semanticMemory     => _as ? "অৰ্থ স্মৃতি"                          : "Semantic Memory";
  String get tapTargetTitle     => _as ? "লক্ষ্যত টেপ কৰক"                     : "Tap the Target";
  String get tapTargetSubtitle  => _as ? "সঠিক বস্তু দেখা গ'লে টেপ কৰক"      : "Tap the right item as it appears";
  String get attention          => _as ? "মনোযোগ"                               : "Attention";
}

