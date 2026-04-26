import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class TikTokAnalysis {
  final int views;
  final int likes;
  final bool esNarcocultura;

  const TikTokAnalysis({
    required this.views,
    required this.likes,
    required this.esNarcocultura,
  });

  factory TikTokAnalysis.fromJson(Map<String, dynamic> j) => TikTokAnalysis(
        views: (j['vistas'] as num?)?.toInt() ?? 0,
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        esNarcocultura: j['es_narcocultura'] == true,
      );
}

class TikTokAnalysisException implements Exception {
  final String message;
  TikTokAnalysisException(this.message);
  @override
  String toString() => message;
}

class TikTokAnalysisService {
  static const String _endpoint = 'http://107.170.14.221/api/tiktok/recibir/';
  static const Duration _timeout = Duration(seconds: 45);

  /// Extrae la primera URL de tiktok.com presente en `text` (puede venir
  /// como mensaje compartido con texto extra).
  static String? extractTikTokUrl(String text) {
    final regex = RegExp(
      r'https?://[^\s]*tiktok\.com[^\s]*',
      caseSensitive: false,
    );
    final m = regex.firstMatch(text);
    return m?.group(0);
  }

  Future<TikTokAnalysis> analyze(String url) async {
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw TikTokAnalysisException(
          'El servidor respondió ${response.statusCode}',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TikTokAnalysis.fromJson(json);
    } on TimeoutException {
      throw TikTokAnalysisException('Tardé mucho en analizar el video');
    } on http.ClientException catch (e) {
      throw TikTokAnalysisException('No pude conectar: ${e.message}');
    } on FormatException {
      throw TikTokAnalysisException('Respuesta inválida del servidor');
    }
  }
}
