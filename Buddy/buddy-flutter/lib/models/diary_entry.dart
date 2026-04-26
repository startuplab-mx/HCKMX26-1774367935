import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'pet_action.dart';

class DiaryEntry {
  final String id;
  final DateTime timestamp;
  final String action;
  final String detail;
  final String emoji;

  DiaryEntry({
    required this.id,
    required this.timestamp,
    required this.action,
    required this.detail,
    required this.emoji,
  });

  factory DiaryEntry.fromAction(PetAction action, String detail) => DiaryEntry(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        action: action.raw,
        detail: detail,
        emoji: action.emoji,
      );

  factory DiaryEntry.system({required String emoji, required String detail}) => DiaryEntry(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        action: 'system',
        detail: detail,
        emoji: emoji,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'action': action,
        'detail': detail,
        'emoji': emoji,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: j['id'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        action: j['action'] as String,
        detail: j['detail'] as String,
        emoji: j['emoji'] as String,
      );
}

class DiaryStore {
  static const _key = 'buddy.diary.v1';

  static Future<List<DiaryEntry>> entries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> append(DiaryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await entries();
    list.insert(0, entry);
    if (list.length > 100) list.removeRange(100, list.length);
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
