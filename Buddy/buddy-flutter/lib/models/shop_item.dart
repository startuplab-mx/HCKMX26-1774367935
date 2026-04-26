import 'package:shared_preferences/shared_preferences.dart';

enum ShopCategory {
  food,
  treats,
  accessories,
  cosmetics;

  String get label => switch (this) {
        ShopCategory.food        => 'Comida',
        ShopCategory.treats      => 'Premios',
        ShopCategory.accessories => 'Accesorios',
        ShopCategory.cosmetics   => 'Cosméticos',
      };
}

class ShopItem {
  final String id;
  final ShopCategory category;
  final String name;
  final String emoji;
  final int price;
  /// Stat name → delta cuando se consume.
  final Map<String, int> effects;

  const ShopItem({
    required this.id,
    required this.category,
    required this.name,
    required this.emoji,
    required this.price,
    required this.effects,
  });
}

class ShopCatalog {
  static const all = <ShopItem>[
    ShopItem(id: 'premium_food', category: ShopCategory.food, name: 'Comida premium', emoji: '🍱', price: 15, effects: {'hunger': 60, 'happiness': 5}),
    ShopItem(id: 'salmon',       category: ShopCategory.food, name: 'Salmón fresco',  emoji: '🐟', price: 25, effects: {'hunger': 80, 'happiness': 10}),
    ShopItem(id: 'milk',         category: ShopCategory.food, name: 'Leche',          emoji: '🥛', price: 10, effects: {'thirst': 50, 'happiness': 5}),
    ShopItem(id: 'energy_drink', category: ShopCategory.food, name: 'Bebida energía', emoji: '⚡', price: 20, effects: {'thirst': 60, 'energy': 30}),
    ShopItem(id: 'cookie',       category: ShopCategory.treats, name: 'Galleta',      emoji: '🍪', price: 8,  effects: {'happiness': 20}),
    ShopItem(id: 'ice_cream',    category: ShopCategory.treats, name: 'Helado',       emoji: '🍦', price: 12, effects: {'happiness': 30, 'energy': -5}),
    ShopItem(id: 'ball',         category: ShopCategory.treats, name: 'Pelota nueva', emoji: '🎾', price: 18, effects: {'happiness': 40}),
    ShopItem(id: 'hat',          category: ShopCategory.accessories, name: 'Sombrero', emoji: '🎩', price: 50, effects: {}),
    ShopItem(id: 'bowtie',       category: ShopCategory.accessories, name: 'Moño',     emoji: '🎀', price: 40, effects: {}),
    ShopItem(id: 'crown',        category: ShopCategory.accessories, name: 'Corona',   emoji: '👑', price: 200, effects: {}),
    ShopItem(id: 'rainbow',      category: ShopCategory.cosmetics, name: 'Aura arcoíris', emoji: '🌈', price: 100, effects: {}),
    ShopItem(id: 'sparkles',     category: ShopCategory.cosmetics, name: 'Brillos',        emoji: '✨', price: 60,  effects: {}),
  ];

  static List<ShopItem> items(ShopCategory c) => all.where((i) => i.category == c).toList();
}

class InventoryStore {
  static const _key = 'buddy.inventory.v1';
  static const _equippedKey = 'buddy.equipped.v1';

  static Future<Set<String>> owned() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  static Future<void> add(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_key) ?? const []).toSet()..add(id);
    await prefs.setStringList(_key, set.toList());
  }

  static Future<bool> has(String id) async => (await owned()).contains(id);

  static Future<String?> getEquippedAccessoryId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_equippedKey);
  }

  static Future<void> setEquippedAccessoryId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_equippedKey);
    } else {
      await prefs.setString(_equippedKey, id);
    }
  }

  static Future<String?> getEquippedAccessoryEmoji() async {
    final id = await getEquippedAccessoryId();
    if (id == null) return null;
    return ShopCatalog.all.where((i) => i.id == id).map((i) => i.emoji).firstOrNull;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
