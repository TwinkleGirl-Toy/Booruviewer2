class JoyreactorTagDto {
  const JoyreactorTagDto({
    required this.name,
    required this.url,
    this.count,
  });

  /// Decoded human-readable tag name (spaces preserved, e.g., "Dark Souls").
  final String name;

  /// Canonical tag name formatted for Boorusama tag chips (underscores instead of spaces).
  String get normalizedName =>
      name.trim().replaceAll(RegExp(r'\s+'), '_');

  /// Original relative or absolute URL to the tag page on JoyReactor.
  final String url;

  /// Post count if available (e.g. from tag search autocomplete/suggestions).
  final int? count;
}
