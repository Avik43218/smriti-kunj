import 'locale_service.dart';

/// All UI strings for the patient app, keyed by [AppLang].
/// Usage: final s = AppStrings(context.watch<LocaleService>().lang);
class AppStrings {
  final AppLang lang;
  const AppStrings(this.lang);

  bool get _as => lang == AppLang.assamese;
  bool get _bn => lang == AppLang.bengali;
  bool get _brx => lang == AppLang.bodo;

  // Helper: pick from 4 languages; falls back to English for any unmatched lang.
  String _t(String en, String as, String bn, String brx) {
    if (_as) return as;
    if (_bn) return bn;
    if (_brx) return brx;
    return en;
  }

  // ── App-wide ──────────────────────────────────────────────────────────────
  String get appName       => _t('Smriti Kunj',           'স্মৃতি কুঞ্জ',           'স্মৃতি কুঞ্জ',         'स्मृति कुञ्ज');
  String get todayActivity => _t("Today's Activities",    'আজিৰ কাৰ্যসূচী',         'আজকের কার্যক্রম',      'आजोनि खामानि');

  // ── Home screen tiles ─────────────────────────────────────────────────────
  String get brainGames          => _t('Brain Games',                     'মগজুৰ খেল',                    'মস্তিষ্কের খেলা',              'मानसिनि खेल');
  String get brainGamesSubtitle  => _t('Play matching & memory games',    'মিলান আৰু স্মৃতিৰ খেল খেলক',  'মেলানো ও স্মৃতির খেলা খেলুন',  'मिलायनाय आरो सोमोनि खेल खेलो');
  String get reminders           => _t('Daily Reminders',                 'দৈনিক স্মাৰণ',                 'দৈনিক স্মারণ',                 'रोजानि सोमोन');
  String get remindersSubtitle   => _t('Medicines, hydration & routine',  'দৰব, পানী আৰু ৰুটিন',          'ওষুধ, জল ও দৈনন্দিন রুটিন',    'दोमोन, पानि आरो रुटिन');
  String get memoryGallery       => _t('Memory Gallery',                  'স্মৃতিৰ গেলেৰী',               'স্মৃতির গ্যালারি',             'सोमोनि गेलेरि');
  String get memoryGallerySubtitle => _t('Family photos & voice notes',   'পৰিয়ালৰ ফটো আৰু কণ্ঠস্বৰ',   'পরিবারের ছবি ও ভয়েস নোট',    'गावनि फटो आरो जोनानि नोट');

  // ── Games screen ──────────────────────────────────────────────────────────
  String get marketTripTitle    => _t('The Market Trip',                  'বজাৰৰ যাত্ৰা',               'বাজারের যাত্রা',               'हाटनि थाखो थानो');
  String get marketTripSubtitle => _t('Remember the shopping list',       'কিনা-বেচাৰ তালিকা মনত ৰাখক', 'কেনাকাটার তালিকা মনে রাখুন',  'कीनायनाय थाखो लिस्ट सोमो');
  String get workingMemory      => _t('Working Memory',                   'কাৰ্যস্মৃতি',                 'কার্যস্মৃতি',                  'खामानि सोमो');
  String get chooseDifficulty   => _t('Choose difficulty:',              'কঠিনতা বাছনি কৰক:',           'কঠিনতা বেছুন:',               'आंखालি बांखो:');
  String get easy               => _t('Easy',                            'সহজ',                          'সহজ',                          'सोलेरनाय');
  String get medium             => _t('Medium',                          'মধ্যম',                        'মাঝারি',                       'मोजांनाय');
  String get hard               => _t('Hard',                            'কঠিন',                         'কঠিন',                         'गोनां');
  String get easyItems          => _t('2 items',                         '২ টা বস্তু',                   '২টি জিনিস',                   '२ बस्तु');
  String get mediumItems        => _t('3 items',                         '৩ টা বস্তু',                   '৩টি জিনিস',                   '३ बस्तु');
  String get hardItems          => _t('6 items',                         '৬ টা বস্তু',                   '৬টি জিনিস',                   '६ बस्तु');
  String get playNow            => _t('Play Now',                        'এতিয়া খেলক',                  'এখনই খেলুন',                  'आबुरो खेलो');
  String get comingSoon         => _t('Coming soon',                     'সোনকালে আহিব',                 'শীঘ্রই আসছে',                  'खालামनायाव दं');

  String get easyPairs          => _t("4 pairs",                         "৪ যোৰ",                        "৪ জোড়া",                      "४ जोर");
  String get mediumPairs        => _t("6 pairs",                         "৬ যোৰ",                        "৬ জোড়া",                      "६ जोर");
  String get hardPairs          => _t("8 pairs",                         "৮ যোৰ",                        "৮ জোড়া",                      "८ जोर");

  // ── Coming-soon game titles / subtitles ───────────────────────────────────
  String get pairMatchTitle     => _t("Pair Matching",                           "যোৰ মিলোৱা",                           "জোড়া মেলানো",                              "जोर मिलायनाय");
  String get pairMatchSubtitle  => _t("Flip cards to find matching pairs",       "মিলন যোৰ বিচাৰিবলৈ কাৰ্ড ওলোটাওক",   "মিলানো জোড়া খুঁজতে কার্ড উলটান",         "मिलायनाय जोर बिलाइ काड उन्दैखो");
  String get episodicMemory     => _t("Episodic Memory",                         "ঘটনাৰ স্মৃতি",                         "ঘটনার স্মৃতি",                              "हाबाफারिनि सोमो");
  String get familyFinderTitle  => _t("Family & Village Finder",                 "পৰিয়াল আৰু গাঁৱৰ বস্তু",             "পরিবার ও গ্রামের বস্তু",                   "गावनि मानुस आरो बस्तु");
  String get familyFinderSub    => _t("Recognise family members & objects",      "পৰিয়ালৰ সদস্য আৰু বস্তু চিনি পাওক", "পরিবারের সদস্য ও বস্তু চিনুন",            "गावनि मानुस आरो बस्तु बुजो");
  String get semanticMemory     => _t("Semantic Memory",                         "অৰ্থ স্মৃতি",                          "অর্থ স্মৃতি",                               "अर्थनि सोमो");
  String get tapTargetTitle     => _t("Tap the Target",                          "লক্ষ্যত টেপ কৰক",                     "লক্ষ্যে ট্যাপ করুন",                       "लक्ष्यो टेप खालामो");
  String get tapTargetSubtitle  => _t("Tap the right item as it appears",        "সঠিক বস্তু দেখা গ'লে টেপ কৰক",       "সঠিক বস্তু দেখলে ট্যাপ করুন",             "सोलोंथाव बस्तु बोखायो हांखो टेप खालामो");
  String get attention          => _t("Attention",                               "মনোযোগ",                               "মনোযোগ",                                   "मनोयोग");

  // ── Sync strings ──────────────────────────────────────────────────────────
  String get syncButton         => _t('Sync',                                    'সিংক',                                 'সিঙ্ক',                                     'सिंक');
  String get helpButton         => _t('Help',                                    'সহায়',                                 'সাহায্য',                                   'नाथाय');
  String get voiceButton        => _t('Voice',                                   'কণ্ঠ',                                  'ভয়েস',                                     'आवाज');
  String get syncActivities     => _t('Sync Activity',                           'তথ্য যোগ কৰক',                         'কার্যক্রম সিঙ্ক করুন',                      'खামानि सिंक');
  String get syncSubtitle       => _t('Send game progress to caregiver',         'অভিভাৱকৰ সৈতে খেলৰ তথ্য প্ৰেৰণ কৰক',  'পরিচর্যাকারীকে গেমের অগ্রগতি পাঠান',      'थालाय लानायখोনি दाहाय थाখো पाठায');
  String get syncing            => _t('Syncing activity...',                     'তথ্য সংমিশ্ৰণ হৈ আছে...',             'কার্যক্রম সিঙ্ক হচ্ছে...',                  'খামানি সিংক হৈ আছে...');
  String get syncSuccess        => _t('Activity synced with caregiver!',         "তথ্য সফলতাৰে প্ৰেৰণ হ'ল!",            'পরিচর্যাকারীর সাথে সিঙ্ক সম্পন্ন!',       'থালাই লানায়খো পাঠাই জাদোঁ!');
  String get syncCleaned        => _t('Local storage wiped clean',               "স্থানীয় সংৰক্ষণ খালী কৰা হ'ল",       'স্থানীয় সঞ্চয় পরিষ্কার করা হয়েছে',      'स्थानीय संग्रह साफ जादों');
  String get allSynced          => _t('All activities already synced',            'সকলো তথ্য ইতিমধ্যে প্ৰেৰণ কৰা হৈছে',  'সমস্ত কার্যক্রম ইতিমধ্যে সিঙ্ক হয়েছে', 'सोबथाय खामानि आगोमनो सिंक जादों');

  // ── In-game UI strings ─────────────────────────────────────────────────────
  String get gameAppBarMarketTrip  => _t('The Market Trip',              'বজাৰৰ যাত্ৰা',               'বাজারের যাত্রা',               'हाटनि थाखो थानो');
  String get gameAppBarTapTarget   => _t('Tap the Target',               'লক্ষ্যত টেপ কৰক',            'লক্ষ্যে ট্যাপ করুন',           'लक्ष्यो टेप खालामो');
  String get gameAppBarPairMatch   => _t('Pair Matching',                'যোৰ মিলোৱা',                  'জোড়া মেলানো',                  'जोर मिलायनाय');

  String get recallTitle           => _t('Select the items that were on your shopping list:',
                                         'বজাৰৰ মোনাত কি কি আছিল বাছনি কৰক:',
                                         'তোমার কেনাকাটার তালিকায় কী কী ছিল বেছুন:',
                                         'हाटनि लिस्टयाव माव-माव बस्तु दंमोन बांखो:');

  String recallSubmit(int count)   => _t('Submit Shopping Bag ($count selected)',
                                         'জমা দিয়ক ($count টা বাছনি কৰা হ\'ল)',
                                         'জমা দিন ($count টি বেছা হয়েছে)',
                                         'जमा खालामो ($count बस्तु बांखायो)');

  String get tapTargetIntroHeading    => _t('Your target:',                       'আপোনাৰ লক্ষ্য:',                     'তোমার লক্ষ্য:',                   'नोংनि लक्ष्य:');
  String get tapTargetIntroInstruction => _t('Tap the card ONLY when your target appears. Do not tap other items.',
                                             'এই বস্তুটো দেখা পালে সোনকালে কাৰ্ডখনত টেপ কৰক। অন্য বস্তুত টেপ নকৰিব।',
                                             'শুধুমাত্র লক্ষ্য দেখলে কার্ডে ট্যাপ করুন। অন্য জিনিসে ট্যাপ করবেন না।',
                                             'केवल नोंनि लक्ष्य बोखायो हांखो काड टेप खालामो। नागिरनाय बस्तुयाव टेप नाखालामो।');
  String get tapTargetStartButton      => _t('Start',                             'আৰম্ভ কৰক',                          'শুরু করুন',                        'हाबो');
  String get tapTargetPlayInstruction  => _t('Tap ONLY when target appears',      'কেৱল লক্ষ্য দেখা পালে টেপ কৰক',     'শুধু লক্ষ্য দেখলে ট্যাপ করুন',    'केवल लक्ष्य बोखायो हांखो टेप खालामो');
  String tapTargetLabel(String name)   => _t('Target: $name',                    'লক্ষ্য: $name',                       'লক্ষ্য: $name',                    'लक्ष्य: $name');

  String get pairMatchInstruction  => _t('Flip cards to find matching pairs',    'মিলন যোৰ বিচাৰিবলৈ কাৰ্ডবোৰ ওলোটাওক', 'মিলানো জোড়া খুঁজতে কার্ড উলটান', 'मिलायनाय जोर बिलाइ काड उन्दैखो');
  String get pairsFoundLabel       => _t('Pairs found:',                         'মিলিত যোৰ:',                          'পাওয়া জোড়া:',                    'मिलायनाय जोर:');

  String get marketTripPromptTitle => _t('Today we need to buy these items:',
                                         'আজি আমি কি কি কিনিব লাগে মনত ৰাখক:',
                                         'আজ আমাদের এই জিনিসগুলো কিনতে হবে মনে রাখুন:',
                                         'दिनै जों बे बे जिनिसफोरखौ बायनांगोन गोसोआव लाखि:');

  String get marketTripReadyButton => _t("I'm Ready to Shop",
                                         'মই মনত ৰাখিলোঁ',
                                         'আমি মনে রেখেছি',
                                         'आं गोसोआव लाखिबाय');

  String get distractorTitle       => _t('Count along: Tap each shape as it appears',
                                         'গণনা কৰক: ওলোৱা প্ৰতিটো চিনত টেপ কৰক',
                                         'গণনা করুন: প্রদর্শিত প্রতিটি চিহ্নে ট্যাপ করুন',
                                         'साननाय: ओंखारनाय मोनफ्रोम सिनआव थु');

  String get playAgain             => _t('Play Again',                           'পুনৰ খেলক',                           'আবার খেলুন',                       'नैथे खेलो');
  String get done                  => _t("Done",                                 "সম্পূৰ্ণ হ'ল",                        "সম্পন্ন",                          "जादों");
}
