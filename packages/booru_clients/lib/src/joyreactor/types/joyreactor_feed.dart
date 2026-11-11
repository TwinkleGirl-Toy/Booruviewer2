enum JoyreactorFeed {
  good,
  best,
  latest,
  abyss,
}

extension JoyreactorFeedX on JoyreactorFeed {
  /// Returns the URL path segment for root feed browsing on JoyReactor.
  /// - Good (Default homepage): `/`
  /// - Best: `/best`
  /// - Latest (New): `/new`
  /// - Abyss (All): `/all`
  String get rootPath => switch (this) {
        JoyreactorFeed.good => '',
        JoyreactorFeed.best => '/best',
        JoyreactorFeed.latest => '/new',
        JoyreactorFeed.abyss => '/all',
      };

  /// Returns the URL suffix for tag browsing on JoyReactor.
  /// - Good (Default tag rating): `/tag/<tag>`
  /// - Best: `/tag/<tag>/best`
  /// - Latest: `/tag/<tag>/new`
  /// - Abyss: `/tag/<tag>/all`
  String get tagSuffix => switch (this) {
        JoyreactorFeed.good => '',
        JoyreactorFeed.best => '/best',
        JoyreactorFeed.latest => '/new',
        JoyreactorFeed.abyss => '/all',
      };

  String get displayName => switch (this) {
        JoyreactorFeed.good => 'Good',
        JoyreactorFeed.best => 'Best',
        JoyreactorFeed.latest => 'Latest (New)',
        JoyreactorFeed.abyss => 'Abyss (All)',
      };

  static JoyreactorFeed? tryParseMetatag(String token) {
    final normalized = token.trim().toLowerCase();
    return switch (normalized) {
      'feed:good' || 'order:good' || 'tab:good' => JoyreactorFeed.good,
      'feed:best' || 'order:best' || 'tab:best' || 'order:score' =>
        JoyreactorFeed.best,
      'feed:new' || 'feed:latest' || 'order:new' || 'order:latest' =>
        JoyreactorFeed.latest,
      'feed:all' || 'feed:abyss' || 'order:all' || 'order:abyss' =>
        JoyreactorFeed.abyss,
      _ => null,
    };
  }
}
