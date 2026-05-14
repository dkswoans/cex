import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const _urlKey = 'SUPABASE_URL';
  static const _publishableKeyKey = 'SUPABASE_PUBLISHABLE_KEY';

  static Future<void> initialize() async {
    final values = await _loadValues();
    final url = values[_urlKey];
    final publishableKey = values[_publishableKeyKey];

    if (url == null ||
        url.isEmpty ||
        publishableKey == null ||
        publishableKey.isEmpty) {
      throw StateError(
        'Supabase settings are missing. Set $_urlKey and $_publishableKeyKey.',
      );
    }

    await Supabase.initialize(url: url, anonKey: publishableKey);
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Future<Map<String, String>> _loadValues() async {
    const defineUrl = String.fromEnvironment(_urlKey);
    const definePublishableKey = String.fromEnvironment(_publishableKeyKey);

    if (defineUrl.isNotEmpty && definePublishableKey.isNotEmpty) {
      return {_urlKey: defineUrl, _publishableKeyKey: definePublishableKey};
    }

    final source = await rootBundle.loadString('supabase.env.json');
    final decoded = jsonDecode(source) as Map<String, dynamic>;

    return decoded.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }
}
