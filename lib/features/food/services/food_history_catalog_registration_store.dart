import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Durable links created by the HISTORY-only "ADD TO FOOD DATABASE" action.
///
/// Historical nutrition snapshots deliberately remain immutable.  The link is
/// therefore stored separately, keyed by the owning record and its stable item
/// identity, rather than attempting to infer registration from a food name.
class FoodHistoryCatalogRegistrationStore {
  FoodHistoryCatalogRegistrationStore._();

  static const _key = 'food_history_catalog_registrations_v1';

  static String legacyItemKey(String mealId, int itemIndex) =>
      'legacy:$mealId:item:$itemIndex';

  static String v2ItemKey(String mealId, String mealItemId) =>
      'v2:$mealId:item:$mealItemId';

  static Future<Map<String, String>> readAll() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const {};
    try {
      final decoded = Map<String, Object?>.from(jsonDecode(raw) as Map);
      return Map.unmodifiable({
        for (final entry in decoded.entries)
          if (entry.value is String) entry.key: entry.value as String,
      });
    } on Object {
      return const {};
    }
  }

  static Future<void> link({
    required String recordItemKey,
    required String catalogId,
  }) async {
    final current = Map<String, String>.from(await readAll())
      ..[recordItemKey] = catalogId;
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(current),
    );
  }
}
