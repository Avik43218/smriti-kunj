import 'package:flutter/material.dart';

/// Supported voice navigation commands.
enum VoiceCommand {
  home,
  game,
  marketTrip,
  tapTarget,
  patternMatch,
  reminders,
  gallery,
  sync,
  help,
  langAssamese,
  langBengali,
  langBodo,
  langEnglish,
  logout,
}

extension VoiceCommandDetails on VoiceCommand {
  String get id {
    switch (this) {
      case VoiceCommand.home:
        return 'home';
      case VoiceCommand.game:
        return 'game';
      case VoiceCommand.marketTrip:
        return 'market_trip';
      case VoiceCommand.tapTarget:
        return 'tap_target';
      case VoiceCommand.patternMatch:
        return 'pattern_match';
      case VoiceCommand.reminders:
        return 'reminders';
      case VoiceCommand.gallery:
        return 'gallery';
      case VoiceCommand.sync:
        return 'sync';
      case VoiceCommand.help:
        return 'help';
      case VoiceCommand.langAssamese:
        return 'lang_assamese';
      case VoiceCommand.langBengali:
        return 'lang_bengali';
      case VoiceCommand.langBodo:
        return 'lang_bodo';
      case VoiceCommand.langEnglish:
        return 'lang_english';
      case VoiceCommand.logout:
        return 'logout';
    }
  }

  String get englishTitle {
    switch (this) {
      case VoiceCommand.home:
        return 'Home';
      case VoiceCommand.game:
        return 'Game';
      case VoiceCommand.marketTrip:
        return 'Market Trip';
      case VoiceCommand.tapTarget:
        return 'Tap the target';
      case VoiceCommand.patternMatch:
        return 'Pattern match';
      case VoiceCommand.reminders:
        return 'Daily Reminders';
      case VoiceCommand.gallery:
        return 'Memory Gallery';
      case VoiceCommand.sync:
        return 'Sync';
      case VoiceCommand.help:
        return 'Help / SOS';
      case VoiceCommand.langAssamese:
        return 'Assamese';
      case VoiceCommand.langBengali:
        return 'Bengali';
      case VoiceCommand.langBodo:
        return 'Bodo';
      case VoiceCommand.langEnglish:
        return 'English';
      case VoiceCommand.logout:
        return 'Logout';
    }
  }

  String get bengaliTitle {
    switch (this) {
      case VoiceCommand.home:
        return 'বাড়ি';
      case VoiceCommand.game:
        return 'খেলা';
      case VoiceCommand.marketTrip:
        return 'বাজারের যাত্রা';
      case VoiceCommand.tapTarget:
        return 'লক্ষ্যে ট্যাপ';
      case VoiceCommand.patternMatch:
        return 'প্যাটার্ন ম্যাচ';
      case VoiceCommand.reminders:
        return 'অনুস্মারক';
      case VoiceCommand.gallery:
        return 'স্মৃতি গ্যালারি';
      case VoiceCommand.sync:
        return 'সিংক';
      case VoiceCommand.help:
        return 'সাহায্য';
      case VoiceCommand.langAssamese:
        return 'অসমীয়া';
      case VoiceCommand.langBengali:
        return 'বাংলা';
      case VoiceCommand.langBodo:
        return 'বড়ো';
      case VoiceCommand.langEnglish:
        return 'ইংরেজি';
      case VoiceCommand.logout:
        return 'লগআউট';
    }
  }

  String get englishSubtitle {
    switch (this) {
      case VoiceCommand.home:
        return 'Return to main home screen';
      case VoiceCommand.game:
        return 'Opens brain games library';
      case VoiceCommand.marketTrip:
        return 'Memory shopping list game';
      case VoiceCommand.tapTarget:
        return 'Attention & reflex game';
      case VoiceCommand.patternMatch:
        return 'Flip & find matching pairs';
      case VoiceCommand.reminders:
        return 'View daily schedule & alerts';
      case VoiceCommand.gallery:
        return 'View photos & family memories';
      case VoiceCommand.sync:
        return 'Synchronize activities with cloud';
      case VoiceCommand.help:
        return 'Emergency alert to caregiver';
      case VoiceCommand.langAssamese:
        return 'Switch app language to Assamese';
      case VoiceCommand.langBengali:
        return 'Switch app language to Bengali';
      case VoiceCommand.langBodo:
        return 'Switch app language to Bodo';
      case VoiceCommand.langEnglish:
        return 'Switch app language to English';
      case VoiceCommand.logout:
        return 'Unpair and exit device';
    }
  }

  String get bengaliSubtitle {
    switch (this) {
      case VoiceCommand.home:
        return 'মূল পর্দায় ফিরে যান';
      case VoiceCommand.game:
        return 'মগজের খেলার তালিকা খুলুন';
      case VoiceCommand.marketTrip:
        return 'বাজারের তালিকা মনে রাখার খেলা';
      case VoiceCommand.tapTarget:
        return 'লক্ষ্য দেখে সঠিক বস্তু স্পর্শ করুন';
      case VoiceCommand.patternMatch:
        return 'মিলন জোড়া খুঁজে বের করার খেলা';
      case VoiceCommand.reminders:
        return 'দৈনিক ওষুধ ও কাজের তালিকা';
      case VoiceCommand.gallery:
        return 'পরিবারের ছবি ও স্মৃতি দেখুন';
      case VoiceCommand.sync:
        return 'ক্লাউডে তথ্য সিংক করুন';
      case VoiceCommand.help:
        return 'জরুরী সাহায্য ও সতর্কবার্তা পাঠান';
      case VoiceCommand.langAssamese:
        return 'ভাষা অসমীয়ায় পরিবর্তন করুন';
      case VoiceCommand.langBengali:
        return 'ভাষা বাংলায় পরিবর্তন করুন';
      case VoiceCommand.langBodo:
        return 'ভাষা বড়োতে পরিবর্তন করুন';
      case VoiceCommand.langEnglish:
        return 'ভাষা ইংরেজিতে পরিবর্তন করুন';
      case VoiceCommand.logout:
        return 'ডিভাইস থেকে প্রস্থান ও আনপেয়ার করুন';
    }
  }

  IconData get icon {
    switch (this) {
      case VoiceCommand.home:
        return Icons.home_rounded;
      case VoiceCommand.game:
        return Icons.extension_rounded;
      case VoiceCommand.marketTrip:
        return Icons.shopping_basket_rounded;
      case VoiceCommand.tapTarget:
        return Icons.touch_app_rounded;
      case VoiceCommand.patternMatch:
        return Icons.flip_rounded;
      case VoiceCommand.reminders:
        return Icons.notifications_active_rounded;
      case VoiceCommand.gallery:
        return Icons.photo_library_rounded;
      case VoiceCommand.sync:
        return Icons.sync_rounded;
      case VoiceCommand.help:
        return Icons.phone_in_talk_rounded;
      case VoiceCommand.langAssamese:
      case VoiceCommand.langBengali:
      case VoiceCommand.langBodo:
      case VoiceCommand.langEnglish:
        return Icons.translate_rounded;
      case VoiceCommand.logout:
        return Icons.logout_rounded;
    }
  }

  Color get color {
    switch (this) {
      case VoiceCommand.home:
        return const Color(0xFF2E2A24); // ink
      case VoiceCommand.game:
        return const Color(0xFFC85A32); // terracotta
      case VoiceCommand.marketTrip:
        return const Color(0xFFE27248);
      case VoiceCommand.tapTarget:
        return const Color(0xFF9E3E1B);
      case VoiceCommand.patternMatch:
        return const Color(0xFFC28B2E); // mugaGold
      case VoiceCommand.reminders:
        return const Color(0xFF6B8A6E); // sageGreen
      case VoiceCommand.gallery:
        return const Color(0xFFC28B2E); // mugaGold
      case VoiceCommand.sync:
        return const Color(0xFF5A7E77);
      case VoiceCommand.help:
        return const Color(0xFFB33927); // alertRed
      case VoiceCommand.langAssamese:
      case VoiceCommand.langBengali:
      case VoiceCommand.langBodo:
      case VoiceCommand.langEnglish:
        return const Color(0xFF8C5E43);
      case VoiceCommand.logout:
        return const Color(0xFFB33927);
    }
  }
}

/// Result of evaluating a voice query.
class VoiceCommandMatch {
  final VoiceCommand command;
  final String matchedCandidate;
  final double confidence;
  final bool isBengali;

  const VoiceCommandMatch({
    required this.command,
    required this.matchedCandidate,
    required this.confidence,
    required this.isBengali,
  });
}

/// Engine that parses transcribed voice input into navigation actions.
class VoiceNavigationService {
  static final VoiceNavigationService instance = VoiceNavigationService._internal();
  VoiceNavigationService._internal();
  factory VoiceNavigationService() => instance;

  // ── English keywords & phrases ──────────────────────────────────────────
  // ── 1. Language Commands (Evaluated first to support "language assamese", etc.)
  static const List<String> _langAssameseRoman = [
    'language assamese',
    'change language assamese',
    'set language assamese',
    'select assamese',
    'switch to assamese',
    'assamese language',
    'assamese',
    'ashamiyo',
    'ashamiya',
    'asamiya',
    'oxomiya',
    'axomiya',
    'axomiya bhasa',
    'asomiya',
    'asami',
    'ashom',
  ];
  static const List<String> _langAssameseNative = [
    'অসমীয়া',
    'অসমীয়া ভাষা',
    'ভাষা অসমীয়া',
    'অসমীয়া',
  ];

  static const List<String> _langBengaliRoman = [
    'language bengali',
    'change language bengali',
    'set language bengali',
    'select bengali',
    'switch to bengali',
    'bengali language',
    'bengali',
    'bangla',
    'bangla bhasha',
    'bangle',
    'bongali',
    'bongo',
    'bangla bhasa',
  ];
  static const List<String> _langBengaliNative = [
    'বাংলা',
    'বাংলা ভাষা',
    'ভাষা বাংলা',
    'বাঙালি',
  ];

  static const List<String> _langBodoRoman = [
    'language bodo',
    'change language bodo',
    'set language bodo',
    'select bodo',
    'switch to bodo',
    'bodo language',
    'bodo',
    'boro',
    'bodo rav',
    'boro rav',
    'bodo bhasha',
    'bodoland',
    'boro bhasa',
  ];
  static const List<String> _langBodoNative = [
    'बड़ो',
    'बड़ो राव',
    'बोरो',
    'বড়ো',
    'বড়ো ভাষা',
  ];

  static const List<String> _langEnglishRoman = [
    'language english',
    'change language english',
    'set language english',
    'select english',
    'switch to english',
    'english language',
    'english',
    'ingreji',
    'ingraji',
    'ingraj',
    'angrezi',
    'angreji',
    'ingreji bhasha',
  ];
  static const List<String> _langEnglishNative = [
    'ইংরেজি',
    'ইংৰাজী',
    'ইংরেজি ভাষা',
    'ইংৰাজী ভাষা',
    'इंग्रजी',
  ];

  // ── 2. Specific Brain Games ──────────────────────────────────────────────
  static const List<String> _marketTripRoman = [
    'market trip',
    'the market trip',
    'market',
    'bazaar',
    'bajar',
    'shopping list',
    'shopping',
    'market game',
    'bazarer jatra',
    'bajarer jatra',
    'bazar list',
    'bajarer khela',
    'bazar trip',
    'bazaror jatra',
    'bazar porua',
    'bazaror khel',
    'hathaini daothai',
    'hatai daothai',
    'bazar thangnai',
  ];
  static const List<String> _marketTripNative = [
    'বাজারের যাত্রা',
    'মার্কেট ট্রিপ',
    'মার্কেট ট্রিপ খেলব',
    'বাজার',
    'মার্কেট',
    'বাজারের খেলা',
    'বাজারের লিস্ট',
    'বাজার ট্রিপ',
    'বজাৰৰ যাত্ৰা',
    'हाथाइनि दावथाय',
  ];

  static const List<String> _tapTargetRoman = [
    'tap the target',
    'tap target',
    'target',
    'tap the target game',
    'tap on target',
    'tap game',
    'target game',
    'touch target',
    'lokkhe tap',
    'lokkho tap',
    'lokkhe click',
    'target tap',
    'lokhyot tap',
    'lokhyo tap',
    'lokhyot sua',
    'thangsoao khochonai',
    'thangso khochon',
    'target ao thunai',
  ];
  static const List<String> _tapTargetNative = [
    'লক্ষ্যে ট্যাপ',
    'লক্ষ্য ট্যাপ',
    'লক্ষ্যে ট্যাপ করুন',
    'লক্ষ্য',
    'টার্গেট',
    'ট্যাপ দ্য টার্গেট',
    'টার্গেটে ট্যাপ',
    'লক্ষ্যে ক্লিক',
    'লক্ষ্যত টেপ',
    'थांसुआव थुनाय',
  ];

  static const List<String> _patternMatchRoman = [
    'pattern match',
    'pattern matching',
    'pattern',
    'pair match',
    'pair matching',
    'matching',
    'pair game',
    'match pair',
    'pairs',
    'jora melano',
    'jora mil',
    'milano',
    'jora match',
    'jura meluwa',
    'jura milan',
    'jura match',
    'pattern meluwa',
    'jora jodainai',
    'jora phin',
    'mwnthay jora',
  ];
  static const List<String> _patternMatchNative = [
    'প্যাটার্ন ম্যাচ',
    'প্যাটার্ন মিলান',
    'প্যাটার্ন ম্যাচিং',
    'জোড়া মেলানো',
    'জোড়া মিলান',
    'জোড়া মেলানো',
    'প্যাটার্ন',
    'জোড়া মিল',
    'মিলানো',
    'যোৰা মিলোৱা',
    'जोरा जोदायनाय',
  ];

  // ── 3. Utility Screens & Buttons ─────────────────────────────────────────
  static const List<String> _homeRoman = [
    'home',
    'go home',
    'back home',
    'take me home',
    'home screen',
    'main screen',
    'main menu',
    'homepage',
    'dashboard',
    'return home',
    'back to home',
    'bari',
    'barie',
    'bari jabo',
    'bari cholo',
    'ghor',
    'ghore',
    'ghore cholo',
    'ghore jabo',
    'asol pata',
    'mool pata',
    'mukhya pata',
    'basa',
    'basay',
    'ghorot',
    'ghoroloi',
    'ghoroloi jao',
    'ghorot jao',
    'ghoroloi bola',
    'mukhya pristha',
    'mool pristha',
    'noh',
    'noh ao',
    'nohao',
    'noha thang',
    'nohao thang',
    'noh thang',
    'gaoni noh',
  ];
  static const List<String> _homeNative = [
    'বাড়ি',
    'বাড়ি',
    'বাড়ী',
    'বাডি',
    'বাড়ি চলুন',
    'বাড়ি যাব',
    'ঘর',
    'ঘরে',
    'ঘরে চলো',
    'ঘরে যাব',
    'মূল পাতা',
    'প্রধান পাতা',
    'হোম',
    'ঘৰ',
    'ঘৰলৈ',
    'ঘৰত',
    'ঘৰলৈ ব’লা',
    'ঘৰলৈ যাওঁ',
    'মুখ্য পৃষ্ঠা',
    'মূল পৃষ্ঠা',
    'न\'',
    'न\'आव',
    'न\'आव थां',
    'न थां',
    'गावनि न',
    'नो',
  ];

  static const List<String> _syncRoman = [
    'sync',
    'sink',
    'backup',
    'backup data',
    'cloud backup',
    'data backup',
    'data sync',
    'synchronize',
    'synchronise',
    'cloud sync',
    'sync now',
    'sync data',
    'sync activities',
    'sync button',
    'upload',
    'upload data',
    'cloud upload',
    'refresh data',
    'singk',
    'sync koro',
    'sync korbo',
    'shongjog',
    'jogajog',
    'totho shongjog',
    'melao',
    'milano',
    'cloud e pathao',
    'pathao',
    'songjog',
    'tothya songjog',
    'singk kora',
    'meluwa',
    'tothya pathuwa',
    'jodai',
    'jodaiphin',
    'mwnthay jodai',
    'daothai jodai',
  ];
  static const List<String> _syncNative = [
    'সিংক',
    'সিঙ্ক',
    'সিংক করুন',
    'সংযোগ',
    'তথ্য সিংক',
    'যোগাযোগ',
    'মেলাও',
    'পাঠাও',
    'তথ্য সংযোগ',
    'সিংক কৰা',
    'তথ্য পঠোৱা',
    'सिंक',
    'जोदाय',
    'जोदायफिन',
    'दावथाय जोदाय',
  ];

  static const List<String> _helpRoman = [
    'help',
    'help me',
    'sos',
    'emergency',
    'danger',
    'call help',
    'call caregiver',
    'need help',
    'urgent',
    'assist',
    'assistance',
    'save me',
    'sahajjo',
    'sahajyo',
    'sahajjo koro',
    'banchao',
    'rokkhya',
    'rokha koro',
    'bipode',
    'bipod',
    'daktar dako',
    'sahajjo chai',
    'madad',
    'sahay',
    'sahai',
    'sahay kora',
    'basa',
    'basuwa',
    'bipodot porisu',
    'sahay lage',
    'sahai lage',
    'joruri',
    'mwnthai',
    'ansunthai',
    'anadw',
    'anadai',
    'ansunthai nangou',
    'ansunthay',
    'khebjep',
    'khatri',
  ];
  static const List<String> _helpNative = [
    'সাহায্য',
    'সাহায্য করুন',
    'বাঁচাও',
    'বিপদ',
    'জরুরী',
    'রক্ষা করো',
    'সাহায্য চাই',
    'এসওএস',
    'সহায়',
    'সহায় কৰা',
    'বচাওক',
    'জৰুৰী',
    'সহায় লাগে',
    'अनसुंथाय',
    'अनसुंथाइ',
    'अननानै अनसुंथाय',
    'अननानै हेफाजाब',
    'खथ्रि',
  ];

  static const List<String> _remindersRoman = [
    'reminders',
    'reminder',
    'daily reminders',
    'daily reminder',
    'notifications',
    'notification',
    'alert',
    'alerts',
    'alarms',
    'alarm',
    'schedule',
    'medicine',
    'medication',
    'daily tasks',
    'tasks',
    'today tasks',
    'my reminders',
    'shomoron',
    'shmarok',
    'onushmarok',
    'mone kora',
    'mone koriye dao',
    'osudh',
    'oshudh',
    'shomoy shuchi',
    'talika',
    'ghonta',
    'shokaler kaj',
    'notiphikeshan',
    'monot peluwa',
    'monot pelowa',
    'xomoron',
    'smanok',
    'aushadh',
    'oukhod',
    'oukhodh',
    'dainik husi',
    'barta',
    'notiphikeson',
    'goso',
    'monot',
    'goso khanghnai',
    'goso khang',
    'gosokhanghnai',
    'mulani som',
    'muli',
    'sanphromnibo',
    'sanphromni',
  ];
  static const List<String> _remindersNative = [
    'অনুস্মারক',
    'স্মারক',
    'মনে করিয়ে দাও',
    'দৈনিক অনুস্মারক',
    'ওষুধ',
    'ওষুধের সময়',
    'ওষুধের সময়',
    'ঔষধ',
    'বিজ্ঞপ্তি',
    'তালিকা',
    'নটিফিকেশন',
    'মনত পেলোৱা',
    'দৈনিক মনত পেলোৱা',
    'স্মাৰক',
    'বাতৰি',
    'জাননী',
    'নটিফিকেচন',
    'गोसोखां होनाय',
    'गोसोखांहनाय',
    'मूलि',
    'सानफ्रोमनि',
  ];

  static const List<String> _galleryRoman = [
    'gallery',
    'memory gallery',
    'memories',
    'photos',
    'photo',
    'pictures',
    'picture',
    'family photos',
    'family pictures',
    'photo album',
    'album',
    'images',
    'show photos',
    'open gallery',
    'chobi',
    'chhobi',
    'tasbir',
    'tasveer',
    'sobi',
    'smriti',
    'smriti gallery',
    'smritikunj',
    'poribarer chobi',
    'chobir album',
    'purono chobi',
    'photoguli',
    'sobi',
    'porialor sobi',
    'puroni sobi',
    'albam',
    'sobir thak',
    'smriti kunjo',
    'mwnthay',
    'nokhorni photo',
    'nokhorni phuto',
    'goso khangnai photo',
    'phuto',
    'phutophwr',
    'gelari',
  ];
  static const List<String> _galleryNative = [
    'গ্যালারি',
    'ছবি',
    'স্মৃতি',
    'স্মৃতি গ্যালারি',
    'পরিবারের ছবি',
    'ছবিগুলো',
    'অ্যালবাম',
    'স্মৃতি গেলেৰী',
    'পৰিয়ালৰ ছবি',
    'गैलरी',
    'नुथाइ',
    'नखरनि फोटो',
    'फोटो',
    'गैलारि',
  ];

  static const List<String> _logoutRoman = [
    'logout',
    'log out',
    'sign out',
    'signout',
    'exit',
    'quit',
    'unpair',
    'disconnect',
    'prosthan',
    'beriye jao',
    'ber hobo',
    'chuti',
    'biday',
    'uloi jao',
    'eri diya',
    'bondho',
    'ongkharnai',
    'onkhar',
    'bontho',
  ];
  static const List<String> _logoutNative = [
    'লগআউট',
    'লগ আউট',
    'লগ-আউট',
    'প্রস্থান',
    'বের হন',
    'লগআউট করুন',
    'লগ আউট করুন',
    'বিদায়',
    'বিদায়',
    'এৰি দিয়া',
    'ओंखारनाय',
  ];

  // ── 4. General Game Library ──────────────────────────────────────────────
  static const List<String> _gameRoman = [
    'game',
    'games',
    'brain game',
    'brain games',
    'play game',
    'play games',
    'open games',
    'open game',
    'khel',
    'khela',
    'khelbo',
    'khela dhula',
    'khelte chai',
    'magojer khela',
    'kheli',
    'khelibo',
    'khelilu',
    'dhimagi khel',
    'khel sun',
    'gelenai',
    'geilun',
    'gelun',
    'gele',
    'geleno',
    'gelehonai',
    'buddhir gelenai',
  ];
  static const List<String> _gameNative = [
    'খেলা',
    'গেম',
    'গেইম',
    'মগজের খেলা',
    'খেলুন',
    'খেলব',
    'খেলাধুলা',
    'খেলতে চাই',
    'খেল',
    'গেলে',
  ];

  /// Parses an array of speech recognition candidates (ordered by confidence)
  /// and returns the highest matching [VoiceCommandMatch] or null if no command is recognized.
  VoiceCommandMatch? parseCandidates(List<String> candidates) {
    if (candidates.isEmpty) return null;

    for (int i = 0; i < candidates.length; i++) {
      final raw = candidates[i];
      final match = parseSingle(raw);
      if (match != null) {
        // Adjust confidence slightly based on candidate rank
        final adjustedConfidence = (match.confidence * (1.0 - (i * 0.1))).clamp(0.1, 1.0);
        return VoiceCommandMatch(
          command: match.command,
          matchedCandidate: match.matchedCandidate,
          confidence: adjustedConfidence,
          isBengali: match.isBengali,
        );
      }
    }
    return null;
  }

  /// Parses a single speech recognition transcription string.
  VoiceCommandMatch? parseSingle(String input) {
    final clean = _normalize(input);
    if (clean.isEmpty) return null;

    // Evaluate in strict priority:
    // 1. Language commands (evaluated first to avoid "assamese game" collision)
    final laScore = _matchScore(clean, _langAssameseRoman, _langAssameseNative);
    if (laScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.langAssamese,
        matchedCandidate: input,
        confidence: laScore.confidence,
        isBengali: laScore.isBengali,
      );
    }

    final lbScore = _matchScore(clean, _langBengaliRoman, _langBengaliNative);
    if (lbScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.langBengali,
        matchedCandidate: input,
        confidence: lbScore.confidence,
        isBengali: lbScore.isBengali,
      );
    }

    final lbdScore = _matchScore(clean, _langBodoRoman, _langBodoNative);
    if (lbdScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.langBodo,
        matchedCandidate: input,
        confidence: lbdScore.confidence,
        isBengali: lbdScore.isBengali,
      );
    }

    final leScore = _matchScore(clean, _langEnglishRoman, _langEnglishNative);
    if (leScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.langEnglish,
        matchedCandidate: input,
        confidence: leScore.confidence,
        isBengali: leScore.isBengali,
      );
    }

    // 2. Specific game commands (evaluated before generic 'game')
    final mtScore = _matchScore(clean, _marketTripRoman, _marketTripNative);
    if (mtScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.marketTrip,
        matchedCandidate: input,
        confidence: mtScore.confidence,
        isBengali: mtScore.isBengali,
      );
    }

    final ttScore = _matchScore(clean, _tapTargetRoman, _tapTargetNative);
    if (ttScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.tapTarget,
        matchedCandidate: input,
        confidence: ttScore.confidence,
        isBengali: ttScore.isBengali,
      );
    }

    final pmScore = _matchScore(clean, _patternMatchRoman, _patternMatchNative);
    if (pmScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.patternMatch,
        matchedCandidate: input,
        confidence: pmScore.confidence,
        isBengali: pmScore.isBengali,
      );
    }

    // 3. Navigation & System Control commands
    final hmScore = _matchScore(clean, _homeRoman, _homeNative);
    if (hmScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.home,
        matchedCandidate: input,
        confidence: hmScore.confidence,
        isBengali: hmScore.isBengali,
      );
    }

    final rmScore = _matchScore(clean, _remindersRoman, _remindersNative);
    if (rmScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.reminders,
        matchedCandidate: input,
        confidence: rmScore.confidence,
        isBengali: rmScore.isBengali,
      );
    }

    final glScore = _matchScore(clean, _galleryRoman, _galleryNative);
    if (glScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.gallery,
        matchedCandidate: input,
        confidence: glScore.confidence,
        isBengali: glScore.isBengali,
      );
    }

    final syScore = _matchScore(clean, _syncRoman, _syncNative);
    if (syScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.sync,
        matchedCandidate: input,
        confidence: syScore.confidence,
        isBengali: syScore.isBengali,
      );
    }

    final hpScore = _matchScore(clean, _helpRoman, _helpNative);
    if (hpScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.help,
        matchedCandidate: input,
        confidence: hpScore.confidence,
        isBengali: hpScore.isBengali,
      );
    }

    final loScore = _matchScore(clean, _logoutRoman, _logoutNative);
    if (loScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.logout,
        matchedCandidate: input,
        confidence: loScore.confidence,
        isBengali: loScore.isBengali,
      );
    }

    // 4. General Game (checked after specific games and commands)
    final gScore = _matchScore(clean, _gameRoman, _gameNative);
    if (gScore.confidence > 0.6) {
      return VoiceCommandMatch(
        command: VoiceCommand.game,
        matchedCandidate: input,
        confidence: gScore.confidence,
        isBengali: gScore.isBengali,
      );
    }

    return null;
  }

  /// Normalizes input text: lowercases, removes punctuation, and canonicalizes nukta variants.
  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('\u09A1\u09BC', '\u09DC') // ড় composed
        .replaceAll('\u09A2\u09BC', '\u09DD') // ঢ় composed
        .replaceAll('\u09AF\u09BC', '\u09DF') // য় composed
        .replaceAll(RegExp(r"""[.,!?\-_:;'"()[\]{}।॥]"""), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  _ScoreResult _matchScore(
    String normalizedInput,
    List<String> romanizedKeywords,
    List<String> nativeKeywords,
  ) {
    // 1. Check Native script matches
    for (final kw in nativeKeywords) {
      final normKw = _normalize(kw);
      if (normKw.isEmpty) continue;
      if (normalizedInput == normKw) {
        return const _ScoreResult(1.0, true);
      }
      // Exact whole-word boundary match
      if (RegExp(r'(^|\s)' + RegExp.escape(normKw) + r'($|\s)').hasMatch(normalizedInput)) {
        return const _ScoreResult(0.95, true);
      }
      // Substring match for longer words/phrases (3+ characters in native script)
      if (normKw.length >= 3 && normalizedInput.contains(normKw)) {
        return const _ScoreResult(0.92, true);
      }
    }

    // 2. Check English / Romanized matches
    for (final kw in romanizedKeywords) {
      final normKw = _normalize(kw);
      if (normKw.isEmpty) continue;
      if (normalizedInput == normKw) {
        return const _ScoreResult(1.0, false);
      }
      // Exact whole-word boundary match
      if (RegExp(r'(^|\s)' + RegExp.escape(normKw) + r'($|\s)').hasMatch(normalizedInput)) {
        return const _ScoreResult(0.95, false);
      }
      // Substring match for longer words/phrases (4+ characters)
      if (normKw.length >= 4 && normalizedInput.contains(normKw)) {
        return const _ScoreResult(0.85, false);
      }
    }

    return const _ScoreResult(0.0, false);
  }
}

class _ScoreResult {
  final double confidence;
  final bool isBengali;
  const _ScoreResult(this.confidence, this.isBengali);
}
