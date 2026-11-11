// Dart imports:
import 'dart:async';

// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import 'parser/pawchive_parser.dart';
import 'types/types.dart';

const kPawchiveDefaultUrl = 'https://pawchive.pw';
const kPawchiveFileHostUrl = 'https://file.pawchive.pw';
const kPawchiveThumbnailHostUrl = 'https://img.pawchive.pw';
const kPawchivePostsPerPage = 50;

class PawchiveClient {
  PawchiveClient({
    Dio? dio,
    String? baseUrl,
    this.fileHostUrl = kPawchiveFileHostUrl,
    this.thumbnailHostUrl = kPawchiveThumbnailHostUrl,
    this.minRequestInterval = const Duration(milliseconds: 1000),
  })  : baseUrl = _normalizeBaseUrl(baseUrl ?? kPawchiveDefaultUrl),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _normalizeBaseUrl(baseUrl ?? kPawchiveDefaultUrl),
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 25),
                headers: {
                  // Pawchive admin policy (gallery-dl #9717) requires an identifiable User-Agent
                  // rather than browser spoofing, and Kemono/Pawchive API routes accept `text/css`.
                  'User-Agent': 'Boorusama/4.6 (https://github.com/khoadng/Boorusama)',
                  'Accept': 'text/css, application/json, text/plain, */*',
                },
              ),
            ),
        _parser = PawchiveParser(
          baseUrl: _normalizeBaseUrl(baseUrl ?? kPawchiveDefaultUrl),
          fileHostUrl: fileHostUrl,
          thumbnailHostUrl: thumbnailHostUrl,
        );

  final String baseUrl;
  final String fileHostUrl;
  final String thumbnailHostUrl;
  final Dio _dio;
  final PawchiveParser _parser;

  /// Minimum interval between requests to respect Pawchive's 1 req/sec policy (gallery-dl #9717).
  final Duration minRequestInterval;
  DateTime? _lastRequestTime;

  /// Cached creator directory (`"$service:$id"` -> creator display name)
  List<PawchiveCreatorDto>? _cachedCreators;
  final Map<String, String> _creatorNamesByKey = {};

  static const Set<String> _kSupportedServices = {
    'patreon',
    'fanbox',
    'fantia',
    'subscribestar',
    'gumroad',
    'boosty',
    'discord',
    'afdian',
  };

  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Fetches posts for the given [tags] / search query and 1-based [page].
  ///
  /// Supported query syntax in Boorusama's search bar:
  /// - Empty query: browses [defaultFeed] (`/api/v1/posts?o=<offset>`, `/api/v1/posts/popular`, or `/api/v1/posts/random`).
  /// - Feed metatags: `feed:recent`, `feed:popular`, `feed:popular_day`, `feed:popular_week`, `feed:popular_month`, `feed:random`.
  /// - Creator filter by ID: `patreon:user:568551`, `fanbox:user:6570768`, or `service:patreon user:568551`
  ///   -> calls `/api/v1/<service>/user/<id>?o=<offset>[&q=<search>]`.
  /// - Creator filter by name: `artist:<name>` or `creator:<name>` -> resolves creator ID from `/api/v1/creators`.
  /// - Tag filter: `tag:<tag>` -> passes `tag=<tag>` to `/api/v1/posts` (and applies client-side tag verification when filtering a creator's posts, per gallery-dl #9667).
  /// - Free-text keywords: passed via `q=<keywords>` to `/api/v1/posts` or `/api/v1/<service>/user/<id>`.
  Future<List<PawchivePostDto>> getPosts({
    List<String> tags = const [],
    int page = 1,
    PawchiveFeed defaultFeed = PawchiveFeed.recent,
    CancelToken? cancelToken,
  }) async {
    final pageResult = await getPage(
      tags: tags,
      page: page,
      defaultFeed: defaultFeed,
      cancelToken: cancelToken,
    );
    return pageResult.posts;
  }

  /// Fetches a full [PawchivePageResultDto] for [tags] and 1-based [page].
  Future<PawchivePageResultDto> getPage({
    List<String> tags = const [],
    int page = 1,
    PawchiveFeed defaultFeed = PawchiveFeed.recent,
    CancelToken? cancelToken,
  }) async {
    final effectivePage = page < 1 ? 1 : page;
    final offset = (effectivePage - 1) * kPawchivePostsPerPage;

    final query = await _resolveSearchQuery(
      tags,
      defaultFeed: defaultFeed,
      cancelToken: cancelToken,
    );

    await _respectRateLimit();

    String endpoint;
    final queryParams = <String, dynamic>{};

    if (query.service != null && query.userId != null) {
      endpoint = '$baseUrl/api/v1/${query.service}/user/${query.userId}';
      if (offset > 0) {
        queryParams['o'] = offset;
      }
      if (query.textQuery.isNotEmpty) {
        queryParams['q'] = query.textQuery;
      }
    } else {
      endpoint = '$baseUrl${query.feed.apiPath}';
      if (query.feed != PawchiveFeed.random && offset > 0) {
        queryParams['o'] = offset;
      }
      if (query.feed.periodParam != null) {
        queryParams['period'] = query.feed.periodParam;
      }
      if (query.textQuery.isNotEmpty) {
        queryParams['q'] = query.textQuery;
      }
      if (query.tagFilters.isNotEmpty) {
        queryParams['tag'] = query.tagFilters.first;
      }
    }

    final response = await _dio.get<String>(
      endpoint,
      queryParameters: queryParams.isEmpty ? null : queryParams,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'Accept': 'text/css, application/json, text/plain, */*',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 404 || statusCode == 410 || response.data == null) {
      return PawchivePageResultDto(posts: const [], offset: offset);
    }

    final parsedPage = _parser.parsePostsPage(
      response.data,
      offset: offset,
      creatorNamesByKey: _creatorNamesByKey,
    );

    // As noted in gallery-dl #9667, Pawchive's creator post endpoint (`/api/v1/<service>/user/<id>`)
    // ignores the `tag=` query parameter, so apply client-side tag filtering if `tag:` was specified.
    if (query.service != null &&
        query.userId != null &&
        query.tagFilters.isNotEmpty) {
      final wanted = query.tagFilters.map((t) => t.toLowerCase()).toSet();
      final filtered = parsedPage.posts.where((post) {
        final lowerPostTags = post.tags.map((t) => t.toLowerCase()).toSet();
        return wanted.every(lowerPostTags.contains);
      }).toList();
      return PawchivePageResultDto(
        posts: filtered,
        offset: offset,
        count: parsedPage.count,
        trueCount: parsedPage.trueCount,
      );
    }

    return parsedPage;
  }

  /// Fetches full post details from `/api/v1/<service>/user/<userId>/post/<postId>`.
  Future<PawchivePostDto?> getPostDetails({
    required String service,
    required String userId,
    required String postId,
    CancelToken? cancelToken,
  }) async {
    await _respectRateLimit();

    final response = await _dio.get<String>(
      '$baseUrl/api/v1/$service/user/$userId/post/$postId',
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'Accept': 'text/css, application/json, text/plain, */*',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode != 200 || response.data == null) {
      return null;
    }

    return _parser.parsePost(
      response.data,
      creatorNamesByKey: _creatorNamesByKey,
    );
  }

  /// Searches creators and tags for Boorusama's autocomplete bar.
  Future<List<PawchiveTagDto>> autocomplete({
    required String query,
    CancelToken? cancelToken,
  }) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];

    final suggestions = <PawchiveTagDto>[];

    // 1. Provide built-in feed & service metatag suggestions
    for (final feedMeta in const [
      'feed:recent',
      'feed:popular_day',
      'feed:popular_week',
      'feed:popular_month',
      'feed:random',
    ]) {
      if (feedMeta.contains(trimmed)) {
        suggestions.add(PawchiveTagDto(name: feedMeta, category: 'meta'));
      }
    }

    for (final service in _kSupportedServices) {
      if (service.contains(trimmed) || 'service:$service'.contains(trimmed)) {
        suggestions.add(
          PawchiveTagDto(name: 'service:$service', category: 'service'),
        );
      }
    }

    // 2. Search cached/fetched creators directory
    try {
      final creators = await getCreators(cancelToken: cancelToken);
      for (final creator in creators) {
        if (creator.name.toLowerCase().contains(trimmed) ||
            creator.id == trimmed) {
          suggestions.add(
            PawchiveTagDto(
              name: creator.searchTag,
              count: creator.favorited,
              category: 'artist',
            ),
          );
          if (suggestions.length >= 25) break;
        }
      }
    } catch (_) {
      // Ignore creator directory errors during autocomplete
    }

    return suggestions;
  }

  /// Fetches and caches the creator roster from `/api/v1/creators` (with fallback to `/api/v1/creators.txt`).
  Future<List<PawchiveCreatorDto>> getCreators({
    CancelToken? cancelToken,
  }) async {
    if (_cachedCreators != null) return _cachedCreators!;

    await _respectRateLimit();

    for (final path in ['/api/v1/creators', '/api/v1/creators.txt']) {
      try {
        final response = await _dio.get<String>(
          '$baseUrl$path',
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.plain,
            headers: const {
              'Accept': 'text/css, application/json, text/plain, */*',
            },
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final parsed = _parser.parseCreators(response.data);
          if (parsed.isNotEmpty) {
            _cachedCreators = parsed;
            for (final c in parsed) {
              _creatorNamesByKey['${c.service}:${c.id}'] = c.name;
            }
            return parsed;
          }
        }
      } catch (_) {
        // Try next creator endpoint
      }
    }

    return const [];
  }

  // ---------------------------------------------------------------------------
  // Internal Query Parser & Rate Limiter
  // ---------------------------------------------------------------------------

  Future<
      ({
        PawchiveFeed feed,
        String? service,
        String? userId,
        String textQuery,
        List<String> tagFilters,
      })> _resolveSearchQuery(
    List<String> rawTags, {
    required PawchiveFeed defaultFeed,
    CancelToken? cancelToken,
  }) async {
    var feed = defaultFeed;
    String? service;
    String? userId;
    String? artistNameFilter;
    final tagFilters = <String>[];
    final textTokens = <String>[];

    for (final raw in rawTags) {
      final token = raw.trim();
      if (token.isEmpty) continue;

      final parsedFeed = PawchiveFeedX.tryParseMetatag(token);
      if (parsedFeed != null) {
        feed = parsedFeed;
        continue;
      }

      final lower = token.toLowerCase();

      // Match `<service>:user:<id>` (e.g. `patreon:user:568551`)
      final compoundMatch =
          RegExp(r'^([a-z0-9_]+):user:([^:\s]+)$', caseSensitive: false)
              .firstMatch(token);
      if (compoundMatch != null) {
        service = compoundMatch.group(1)!.toLowerCase();
        userId = compoundMatch.group(2)!;
        continue;
      }

      if (lower.startsWith('service:')) {
        final s = token.substring(8).trim().toLowerCase();
        if (s.isNotEmpty) service = s;
        continue;
      }

      if (lower.startsWith('user:') || lower.startsWith('creator_id:')) {
        final u = token.substring(token.indexOf(':') + 1).trim();
        if (u.isNotEmpty) userId = u;
        continue;
      }

      if (lower.startsWith('artist:') || lower.startsWith('creator:')) {
        final a = token
            .substring(token.indexOf(':') + 1)
            .trim()
            .replaceAll('_', ' ');
        if (a.isNotEmpty) artistNameFilter = a;
        continue;
      }

      if (lower.startsWith('tag:')) {
        final t = token.substring(4).trim().replaceAll('_', ' ');
        if (t.isNotEmpty) tagFilters.add(t);
        continue;
      }

      if (_kSupportedServices.contains(lower) && service == null) {
        service = lower;
        continue;
      }

      textTokens.add(token.replaceAll('_', ' '));
    }

    // If an artist name was specified without an explicit `userId`, look up in creator directory
    if (userId == null && artistNameFilter != null) {
      final creators = await getCreators(cancelToken: cancelToken);
      final lowerArtist = artistNameFilter.toLowerCase();
      final matched = creators.where((c) {
        final matchesName = c.name.toLowerCase() == lowerArtist ||
            (c.publicId?.toLowerCase() == lowerArtist);
        final matchesService = service == null || c.service == service;
        return matchesName && matchesService;
      }).firstOrNull;

      if (matched != null) {
        service = matched.service;
        userId = matched.id;
      } else {
        textTokens.add(artistNameFilter);
      }
    }

    if (userId != null && service == null) {
      service = 'patreon';
    }

    return (
      feed: feed,
      service: service,
      userId: userId,
      textQuery: textTokens.join(' ').trim(),
      tagFilters: tagFilters,
    );
  }

  Future<void> _respectRateLimit() async {
    final last = _lastRequestTime;
    final now = DateTime.now();
    if (last != null) {
      final elapsed = now.difference(last);
      if (elapsed < minRequestInterval) {
        await Future<void>.delayed(minRequestInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }
}
