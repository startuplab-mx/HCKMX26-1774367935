import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class ToastData {
  final String id;
  final String emoji;
  final String title;
  final String detail;
  ToastData({required this.id, required this.emoji, required this.title, required this.detail});
}

/// Singleton + ChangeNotifier. La HomeView se suscribe y renderiza el banner.
class ToastQueue extends ChangeNotifier {
  static final ToastQueue instance = ToastQueue._();
  ToastQueue._();

  ToastData? _current;
  ToastData? get current => _current;

  Timer? _timer;

  void show({
    required String emoji,
    required String title,
    required String detail,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    _timer?.cancel();
    _current = ToastData(id: const Uuid().v4(), emoji: emoji, title: title, detail: detail);
    notifyListeners();
    final id = _current!.id;
    _timer = Timer(duration, () {
      if (_current?.id == id) {
        _current = null;
        notifyListeners();
      }
    });
  }
}
