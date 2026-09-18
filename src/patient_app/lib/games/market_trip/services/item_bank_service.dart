import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/market_item.dart';

enum GameDifficulty { easy, medium, hard }

class ItemBankService {
  final Random _random;

  ItemBankService({Random? random}) : _random = random ?? Random();

  /// Embedded fallback data in case asset loading is unavailable.
  static const String _fallbackJsonString = '''
{
  "items": [
    {
      "id": "bamboo_shoot",
      "category": "vegetables",
      "visual_group": "green_stem",
      "translations": {"en": "Bamboo Shoots", "as": "বাঁহৰ গাজ"},
      "icon_name": "eco"
    },
    {
      "id": "mustard_oil",
      "category": "household",
      "visual_group": "liquid_bottle",
      "translations": {"en": "Mustard Oil", "as": "সৰিয়হৰ তেল"},
      "icon_name": "opacity"
    },
    {
      "id": "ginger",
      "category": "spices",
      "visual_group": "root_bulb",
      "translations": {"en": "Fresh Ginger", "as": "আদা"},
      "icon_name": "spa"
    },
    {
      "id": "tea_leaves",
      "category": "household",
      "visual_group": "green_stem",
      "translations": {"en": "Assam Tea Leaves", "as": "চাহ পাত"},
      "icon_name": "emoji_food_beverage"
    },
    {
      "id": "turmeric",
      "category": "spices",
      "visual_group": "yellow_round",
      "translations": {"en": "Turmeric Root", "as": "হালধি"},
      "icon_name": "grain"
    },
    {
      "id": "bamboo_hat_japi",
      "category": "household",
      "visual_group": "woven_craft",
      "translations": {"en": "Traditional Japi", "as": "জাপি"},
      "icon_name": "style"
    },
    {
      "id": "lemon",
      "category": "fruits",
      "visual_group": "yellow_round",
      "translations": {"en": "Assam Kazi Nemu Lemon", "as": "কাজী টেঙা"},
      "icon_name": "nature"
    },
    {
      "id": "green_chili",
      "category": "vegetables",
      "visual_group": "green_stem",
      "translations": {"en": "Green Chili", "as": "কেঁচা লঙ্কা"},
      "icon_name": "local_fire_department"
    },
    {
      "id": "garlic",
      "category": "spices",
      "visual_group": "root_bulb",
      "translations": {"en": "Garlic Cloves", "as": "নহৰু"},
      "icon_name": "brightness_low"
    },
    {
      "id": "jackfruit",
      "category": "fruits",
      "visual_group": "green_stem",
      "translations": {"en": "Ripe Jackfruit", "as": "কঠাল"},
      "icon_name": "park"
    },
    {
      "id": "papaya",
      "category": "fruits",
      "visual_group": "yellow_round",
      "translations": {"en": "Sweet Papaya", "as": "অমিতা"},
      "icon_name": "local_florist"
    },
    {
      "id": "betel_nut",
      "category": "household",
      "visual_group": "root_bulb",
      "translations": {"en": "Betel Nut (Tamul)", "as": "তামোল"},
      "icon_name": "circle"
    },
    {
      "id": "brass_jug_lota",
      "category": "household",
      "visual_group": "liquid_bottle",
      "translations": {"en": "Brass Water Lota", "as": "পিতলৰ লোটা"},
      "icon_name": "water_drop"
    },
    {
      "id": "bamboo_basket",
      "category": "household",
      "visual_group": "woven_craft",
      "translations": {"en": "Bamboo Basket", "as": "বাঁহৰ পাচি"},
      "icon_name": "shopping_basket"
    },
    {
      "id": "earthen_lamp",
      "category": "household",
      "visual_group": "woven_craft",
      "translations": {"en": "Earthen Clay Lamp", "as": "মাটিৰ চাকি"},
      "icon_name": "lightbulb"
    },
    {
      "id": "silk_shawl",
      "category": "household",
      "visual_group": "cloth",
      "translations": {"en": "Muga Silk Shawl", "as": "মুগা চাদৰ"},
      "icon_name": "checkroom"
    }
  ]
}
''';

  /// Loads the item bank from `assets/data/item_bank.json` or fallback.
  Future<List<MarketItem>> loadItemBank() async {
    String jsonString;
    try {
      jsonString = await rootBundle.loadString('assets/data/item_bank.json');
    } catch (_) {
      jsonString = _fallbackJsonString;
    }

    final decoded = json.decode(jsonString) as Map<String, dynamic>;
    final rawList = decoded['items'] as List<dynamic>? ?? [];
    return rawList
        .map((e) => MarketItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Select prompt items based on current difficulty.
  /// - Easy: 2 items
  /// - Medium: 3-4 items (3)
  /// - Hard: 6-8 items (6)
  List<MarketItem> selectPromptItems({
    required List<MarketItem> bank,
    required GameDifficulty difficulty,
  }) {
    if (bank.isEmpty) return [];

    int targetCount;
    switch (difficulty) {
      case GameDifficulty.easy:
        targetCount = 2;
        break;
      case GameDifficulty.medium:
        targetCount = 3;
        break;
      case GameDifficulty.hard:
        targetCount = 6;
        break;
    }

    final copy = List<MarketItem>.from(bank)..shuffle(_random);
    return copy.take(min(targetCount, copy.length)).toList();
  }

  /// Generate recall grid (prompt items + decoy items) based on difficulty.
  /// - Easy: 2 prompt items + 4 distinct decoys = 6 cards
  /// - Medium: 3 prompt items + 5 decoys (some visually similar) = 8 cards
  /// - Hard: 6 prompt items + 6 decoys (visually/semantically similar) = 12 cards
  List<MarketItem> generateRecallGrid({
    required List<MarketItem> bank,
    required List<MarketItem> promptItems,
    required GameDifficulty difficulty,
  }) {
    final promptIds = promptItems.map((e) => e.id).toSet();
    final availableDecoys = bank.where((e) => !promptIds.contains(e.id)).toList();

    int decoyCount;
    switch (difficulty) {
      case GameDifficulty.easy:
        decoyCount = 4;
        break;
      case GameDifficulty.medium:
        decoyCount = 5;
        break;
      case GameDifficulty.hard:
        decoyCount = 6;
        break;
    }

    List<MarketItem> selectedDecoys = [];

    if (difficulty == GameDifficulty.easy) {
      // Easy: visually distinct decoys
      availableDecoys.shuffle(_random);
      selectedDecoys = availableDecoys.take(decoyCount).toList();
    } else {
      // Medium & Hard: prioritize decoys with matching visual_group or category
      final promptGroups = promptItems.map((e) => e.visualGroup).toSet();
      final promptCategories = promptItems.map((e) => e.category).toSet();

      final similarDecoys = availableDecoys.where((d) {
        return promptGroups.contains(d.visualGroup) || promptCategories.contains(d.category);
      }).toList();

      similarDecoys.shuffle(_random);
      selectedDecoys.addAll(similarDecoys.take(decoyCount));

      // Fill remaining if needed
      if (selectedDecoys.length < decoyCount) {
        final remainingDecoys = availableDecoys
            .where((d) => !selectedDecoys.contains(d))
            .toList()
          ..shuffle(_random);
        selectedDecoys.addAll(remainingDecoys.take(decoyCount - selectedDecoys.length));
      }
    }

    final grid = <MarketItem>[...promptItems, ...selectedDecoys];
    grid.shuffle(_random);
    return grid;
  }
}
