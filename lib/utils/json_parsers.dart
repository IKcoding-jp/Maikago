/// Firestore など信頼できない JSON を安全に変換するヘルパー群（Issue #164）。
///
/// 別バージョンのクライアントや手動修正で型不一致・不正値が混入しても、
/// `as` キャストで例外を投げず、可能な範囲で復元する。
library;

/// [value] を int へ変換する。num・数値文字列に対応し、変換不能なら [fallback]。
int parseIntSafe(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? num.tryParse(value)?.toInt() ?? fallback;
  }
  return fallback;
}

/// [value] を nullable な int へ変換する。null・変換不能なら null（budget 等向け）。
int? parseNullableIntSafe(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? num.tryParse(value)?.toInt();
  }
  return null;
}

/// [value] を double へ変換する。num・数値文字列に対応し、変換不能なら [fallback]。
double parseDoubleSafe(dynamic value, {double fallback = 0.0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// [value] が ISO8601 文字列なら DateTime に変換する。不正・null・非文字列なら null。
DateTime? parseDateTimeSafe(dynamic value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// [value] を bool へ変換する。bool・"true"/"false" 文字列・数値(0以外=true)に対応し、
/// 変換不能なら [fallback]。型不一致でも例外を投げないため（Issue #164）。
bool parseBoolSafe(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
  }
  if (value is num) return value != 0;
  return fallback;
}
