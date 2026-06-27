/// Shared helpers for normalizing backend JSON into UI-friendly maps.
class ApiParse {
  static List<Map<String, dynamic>> asMapList(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Map<String, dynamic> asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  static String field(Map<String, dynamic> item, List<String> keys,
      {String fallback = ''}) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  static int? intField(Map<String, dynamic> item, List<String> keys) {
    final raw = field(item, keys, fallback: '');
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }
}
