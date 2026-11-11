enum PawchiveFeed {
  recent,
  popularDay,
  popularWeek,
  popularMonth,
  random,
}

extension PawchiveFeedX on PawchiveFeed {
  String get displayName => switch (this) {
        PawchiveFeed.recent => 'Recent',
        PawchiveFeed.popularDay => 'Popular (Day)',
        PawchiveFeed.popularWeek => 'Popular (Week)',
        PawchiveFeed.popularMonth => 'Popular (Month)',
        PawchiveFeed.random => 'Random',
      };

  String get apiPath => switch (this) {
        PawchiveFeed.recent => '/api/v1/posts',
        PawchiveFeed.popularDay ||
        PawchiveFeed.popularWeek ||
        PawchiveFeed.popularMonth =>
          '/api/v1/posts/popular',
        PawchiveFeed.random => '/api/v1/posts/random',
      };

  String? get periodParam => switch (this) {
        PawchiveFeed.popularDay => 'day',
        PawchiveFeed.popularWeek => 'week',
        PawchiveFeed.popularMonth => 'month',
        _ => null,
      };

  static PawchiveFeed? tryParseMetatag(String token) {
    final normalized = token.trim().toLowerCase();
    return switch (normalized) {
      'feed:recent' || 'order:recent' || 'order:new' => PawchiveFeed.recent,
      'feed:popular' ||
      'feed:popular_day' ||
      'order:popular' ||
      'order:day' =>
        PawchiveFeed.popularDay,
      'feed:popular_week' || 'order:week' => PawchiveFeed.popularWeek,
      'feed:popular_month' || 'order:month' || 'order:score' =>
        PawchiveFeed.popularMonth,
      'feed:random' || 'order:random' => PawchiveFeed.random,
      _ => null,
    };
  }
}
