/// Builds `searchKeywords` for a note so the app can search with Firestore's
/// `array-contains` (Firestore has no full-text search; Phase 9 may move to
/// Algolia/Typesense).
///
/// Every word, plus every prefix of each word (2+ letters), lower-case:
/// "Data Structures" → [da, dat, data, st, str, …, structures].
/// A search for "struc" then matches with `array-contains: 'struc'`.
List<String> buildSearchKeywords(Iterable<String?> texts, {int max = 300}) {
  final words = <String>{};
  for (final text in texts) {
    if (text == null) continue;
    for (final raw in text.toLowerCase().split(RegExp(r'[^a-z0-9+#]+'))) {
      if (raw.isNotEmpty) words.add(raw);
    }
  }

  final keywords = <String>{};
  for (final word in words) {
    if (word.length < 2) {
      keywords.add(word);
      continue;
    }
    final limit = word.length > 20 ? 20 : word.length;
    for (var i = 2; i <= limit; i++) {
      keywords.add(word.substring(0, i));
    }
    keywords.add(word);
  }

  final list = keywords.toList()..sort();
  return list.length > max ? list.sublist(0, max) : list;
}
