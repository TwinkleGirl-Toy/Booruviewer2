// Dart imports:
import 'dart:async';

// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import 'parser/joyreactor_html_parser.dart';
import 'types/types.dart';

const kJoyreactorDefaultUrl = 'https://joyreactor.cc';

class JoyreactorClient {
  JoyreactorClient({
    Dio? dio,
    String? baseUrl,
    this.minRequestInterval = const Duration(milliseconds: 350),
  })  : baseUrl = _normalizeBaseUrl(baseUrl ?? kJoyreactorDefaultUrl),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _normalizeBaseUrl(baseUrl ?? kJoyreactorDefaultUrl),
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 25),
                headers: {
                  'Accept':
                      'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
                  'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
                  'Referer':
                      '${_normalizeBaseUrl(baseUrl ?? kJoyreactorDefaultUrl)}/',
                },
              ),
            ),
        _parser = JoyreactorHtmlParser(
          baseUrl: _normalizeBaseUrl(baseUrl ?? kJoyreactorDefaultUrl),
        );

  final String baseUrl;
  final Dio _dio;
  final JoyreactorHtmlParser _parser;

  /// Minimum interval between consecutive HTTP requests to respect JoyReactor's rate limits.
  final Duration minRequestInterval;
  DateTime? _lastRequestTime;

  /// Cache of discovered next-page URLs keyed by `(canonicalQueryKey, appPage)`.
  /// Because JoyReactor uses reverse-numbered pagination (`span.current` -> `a.next`),
  /// we store the exact `nextPageUrl` discovered from page `N`'s HTML navigation links
  /// so requesting page `N + 1` follows the website's actual link.
  final Map<String, String> _discoveredPageUrls = {};

  /// Tracks seen post IDs per canonical query session to prevent duplicate posts
  /// when new posts shift reverse-numbered pages during infinite scrolling.
  final Map<String, Set<int>> _seenPostIdsByQuery = {};

  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Clears cached pagination links and deduplication sets (e.g. on pull-to-refresh).
  void resetPaginationCache([String? queryKey]) {
    if (queryKey == null) {
      _discoveredPageUrls.clear();
      _seenPostIdsByQuery.clear();
    } else {
      _discoveredPageUrls.removeWhere((k, _) => k.startsWith('$queryKey|'));
      _seenPostIdsByQuery.remove(queryKey);
    }
  }

  /// Fetches posts for the given [tags] / search query, [feed] tab, and 1-based [page].
  ///
  /// Supported query forms:
  /// - Empty tags: browses root feed (`Good` -> `/`, `Best` -> `/best`, `Latest` -> `/new`, `Abyss` -> `/all`).
  /// - Feed metatags: `feed:good`, `feed:best`, `feed:new`, `feed:latest`, `feed:abyss`, `feed:all`, `order:score`.
  /// - Single tag: browses `/tag/<encoded_tag>[/<feed_suffix>]`.
  /// - Full-text / multi-term search or `search:<query>` / `q:<query>`: uses JoyReactor's `/search?q=<query>` endpoint.
  /// - User uploads (`user:<username>`): browses `/user/<username>`.
  Future<List<JoyreactorPostDto>> getPosts({
    List<String> tags = const [],
    int page = 1,
    JoyreactorFeed defaultFeed = JoyreactorFeed.good,
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

  /// Fetches a full [JoyreactorPageResultDto] including pagination links and deduplicated posts.
  Future<JoyreactorPageResultDto> getPage({
    List<String> tags = const [],
    int page = 1,
    JoyreactorFeed defaultFeed = JoyreactorFeed.good,
    CancelToken? cancelToken,
  }) async {
    final resolvedQuery = _resolveQuery(tags, defaultFeed: defaultFeed);
    final queryKey = resolvedQuery.cacheKey;

    if (page <= 1) {
      resetPaginationCache(queryKey);
    }

    String targetUrl;
    if (page <= 1) {
      targetUrl = resolvedQuery.initialUrl;
    } else {
      final cachedUrl = _discoveredPageUrls['$queryKey|$page'];
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        targetUrl = cachedUrl;
      } else {
        // If page N was requested without page N-1 in cache, fetch page 1 first
        // to discover the actual pagination link rather than guessing reverse page numbers.
        final firstPage = await _fetchAndParseUrl(
          resolvedQuery.initialUrl,
          cancelToken: cancelToken,
        );
        if (firstPage.nextPageUrl == null || firstPage.nextPageUrl!.isEmpty) {
          return JoyreactorPageResultDto(
            posts: const [],
            currentUrl: resolvedQuery.initialUrl,
          );
        }
        _discoveredPageUrls['$queryKey|2'] = firstPage.nextPageUrl!;
        targetUrl = _resolveSteppedPaginationUrl(
          firstPage: firstPage,
          targetAppPage: page,
        );
      }
    }

    final result = await _fetchAndParseUrl(
      targetUrl,
      cancelToken: cancelToken,
    );

    // Guard against JoyReactor's last-page redirect back to page 1 (which would loop infinitely)
    if (page > 1 && _isRedirectToFirstPage(targetUrl, result.currentUrl)) {
      return JoyreactorPageResultDto(
        posts: const [],
        currentUrl: result.currentUrl,
      );
    }

    // Store discovered nextPageUrl for `page + 1`
    if (result.nextPageUrl != null && result.nextPageUrl!.isNotEmpty) {
      _discoveredPageUrls['$queryKey|${page + 1}'] = result.nextPageUrl!;
    }

    // Deduplicate posts across pages within the same query session
    final seenIds = _seenPostIdsByQuery.putIfAbsent(queryKey, () => <int>{});
    final uniquePosts = <JoyreactorPostDto>[];
    for (final post in result.posts) {
      if (seenIds.add(post.id)) {
        uniquePosts.add(post);
      }
    }

    return JoyreactorPageResultDto(
      posts: uniquePosts,
      currentUrl: result.currentUrl,
      currentPageNumber: result.currentPageNumber,
      nextPageUrl: result.nextPageUrl,
      prevPageUrl: result.prevPageUrl,
    );
  }

  /// Fetches a single post by its numeric [id] (`https://joyreactor.cc/post/<id>`).
  Future<JoyreactorPostDto?> getPost({
    required int id,
    CancelToken? cancelToken,
  }) async {
    // Handle synthetic sub-post IDs generated for multi-image posts:
    // If id > 1000000000, recover the parent JoyReactor post ID `id ~/ 100`.
    final canonicalPostId = id > 1000000000 ? id ~/ 100 : id;
    final url = '$baseUrl/post/$canonicalPostId';
    final result = await _fetchAndParseUrl(url, cancelToken: cancelToken);
    if (result.posts.isEmpty) return null;
    return result.posts.firstWhere(
      (p) => p.id == canonicalPostId,
      orElse: () => result.posts.first,
    );
  }

  /// Searches for tags matching [query] via JoyReactor's tag autocomplete / search page.
  Future<List<JoyreactorTagDto>> searchTags({
    required String query,
    CancelToken? cancelToken,
  }) async {
    final trimmed = query.trim().replaceAll('_', ' ');
    if (trimmed.isEmpty) return const [];

    await _respectRateLimit();

    try {
      // 1. Try JoyReactor's autocomplete endpoint (`/autocomplete/tag?term=<query>`)
      final autoResponse = await _dio.get<String>(
        '$baseUrl/autocomplete/tag',
        queryParameters: {'term': trimmed},
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (autoResponse.statusCode == 200 &&
          autoResponse.data != null &&
          autoResponse.data!.trim().isNotEmpty) {
        final suggestions = _parser.parseTagSuggestions(autoResponse.data!);
        if (suggestions.isNotEmpty) return suggestions;
      }
    } catch (_) {
      // Fall back to HTML search page parsing
    }

    try {
      // 2. Fallback: fetch `/search?q=<query>` and extract matching tag links
      final searchResponse = await _dio.get<String>(
        '$baseUrl/search',
        queryParameters: {'q': trimmed},
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (searchResponse.statusCode == 200 && searchResponse.data != null) {
        final suggestions = _parser.parseTagSuggestions(searchResponse.data!);
        if (suggestions.isNotEmpty) return suggestions;
      }
    } catch (_) {
      // Ignore network failure and return synthesized tag entry
    }

    return [
      JoyreactorTagDto(
        name: trimmed,
        url: '$baseUrl/tag/${JoyreactorHtmlParser.encodeTagForPath(trimmed)}',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Internal Query Resolution & HTTP Helpers
  // ---------------------------------------------------------------------------

  ({String initialUrl, String cacheKey}) _resolveQuery(
    List<String> rawTags, {
    required JoyreactorFeed defaultFeed,
  }) {
    var feed = defaultFeed;
    String? userFilter;
    String? explicitSearchQuery;
    final cleanTerms = <String>[];

    for (final rawToken in rawTags) {
      final token = rawToken.trim();
      if (token.isEmpty) continue;

      final parsedFeed = JoyreactorFeedX.tryParseMetatag(token);
      if (parsedFeed != null) {
        feed = parsedFeed;
        continue;
      }

      final lower = token.toLowerCase();
      if (lower.startsWith('user:')) {
        final u = token.substring(5).trim();
        if (u.isNotEmpty) userFilter = u;
        continue;
      }
      if (lower.startsWith('search:') || lower.startsWith('q:')) {
        final q = token.substring(token.indexOf(':') + 1).trim();
        if (q.isNotEmpty) {
          explicitSearchQuery =
              explicitSearchQuery == null ? q : '$explicitSearchQuery $q';
        }
        continue;
      }

      cleanTerms.add(token);
    }

    // 1. Explicit full-text search (`search:foo` or `q:foo`)
    if (explicitSearchQuery != null && explicitSearchQuery.isNotEmpty) {
      final q = explicitSearchQuery.replaceAll('_', ' ').trim();
      final uri = Uri.parse('$baseUrl/search').replace(
        queryParameters: {
          'q': q,
          if (userFilter != null && userFilter.isNotEmpty) 'user': userFilter,
        },
      );
      return (
        initialUrl: uri.toString(),
        cacheKey: 'search|$q|${userFilter ?? ''}',
      );
    }

    // 2. User posts browsing (`user:<username>`)
    if (userFilter != null && userFilter.isNotEmpty && cleanTerms.isEmpty) {
      final encodedUser = Uri.encodeComponent(userFilter);
      final url = '$baseUrl/user/$encodedUser';
      return (initialUrl: url, cacheKey: 'user|$encodedUser');
    }

    // 3. No tags -> Root feed browsing (`Good` `/`, `Best` `/best`, `Latest` `/new`, `Abyss` `/all`)
    if (cleanTerms.isEmpty) {
      final path = feed.rootPath;
      final url = path.isEmpty ? '$baseUrl/' : '$baseUrl$path';
      return (initialUrl: url, cacheKey: 'feed|${feed.name}');
    }

    // 4. Single tag -> Tag browsing (`/tag/<encodedTag>[/<feedSuffix>]`)
    if (cleanTerms.length == 1) {
      final singleTag = cleanTerms.first;
      final encodedTag = JoyreactorHtmlParser.encodeTagForPath(singleTag);
      final suffix = feed.tagSuffix;
      final url = '$baseUrl/tag/$encodedTag$suffix';
      return (
        initialUrl: url,
        cacheKey: 'tag|${singleTag.toLowerCase()}|${feed.name}',
      );
    }

    // 5. Multiple search tokens -> JoyReactor full-text / multi-tag search (`/search?q=...`)
    final combinedQuery =
        cleanTerms.map((t) => t.replaceAll('_', ' ')).join(' ').trim();
    final uri = Uri.parse('$baseUrl/search').replace(
      queryParameters: {
        'q': combinedQuery,
        if (userFilter != null && userFilter.isNotEmpty) 'user': userFilter,
      },
    );
    return (
      initialUrl: uri.toString(),
      cacheKey: 'search|$combinedQuery|${userFilter ?? ''}',
    );
  }

  String _resolveSteppedPaginationUrl({
    required JoyreactorPageResultDto firstPage,
    required int targetAppPage,
  }) {
    final nextUrl = firstPage.nextPageUrl!;
    if (targetAppPage == 2) return nextUrl;

    // If the site uses reverse page numbers (e.g. current=1000, next=.../999),
    // compute the offset from the discovered `nextPageUrl` when jumping directly to page > 2.
    final nextPageNumMatch = RegExp(r'/(\d+)(\?.*)?$').firstMatch(nextUrl);
    if (nextPageNumMatch != null) {
      final secondPageNum = int.tryParse(nextPageNumMatch.group(1)!);
      final firstPageNum = firstPage.currentPageNumber;
      if (secondPageNum != null) {
        final isDescending =
            firstPageNum != null ? firstPageNum > secondPageNum : secondPageNum > 2;
        final stepsFromPage2 = targetAppPage - 2;
        final computedPageNum = isDescending
            ? (secondPageNum - stepsFromPage2)
            : (secondPageNum + stepsFromPage2);
        if (computedPageNum > 0) {
          final queryPart = nextPageNumMatch.group(2) ?? '';
          return nextUrl.replaceFirst(
            RegExp(r'/(\d+)(\?.*)?$'),
            '/$computedPageNum$queryPart',
          );
        }
      }
    }
    return nextUrl;
  }

  bool _isRedirectToFirstPage(String requestedUrl, String effectiveUrl) {
    if (requestedUrl == effectiveUrl) return false;
    final reqUri = Uri.tryParse(requestedUrl);
    final effUri = Uri.tryParse(effectiveUrl);
    if (reqUri == null || effUri == null) return false;

    // On JoyReactor, requesting past the oldest page (e.g. `/tag/art/1`) redirects to `/tag/art`
    final reqSegments =
        reqUri.pathSegments.where((s) => s.isNotEmpty).toList();
    final effSegments =
        effUri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (reqSegments.length > effSegments.length &&
        int.tryParse(reqSegments.last) != null) {
      return true;
    }
    return false;
  }

  Future<JoyreactorPageResultDto> _fetchAndParseUrl(
    String url, {
    CancelToken? cancelToken,
  }) async {
    await _respectRateLimit();

    final response = await _dio.get<String>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 404 || statusCode == 410) {
      return JoyreactorPageResultDto(
        posts: const [],
        currentUrl: url,
      );
    }

    if (statusCode == 429 || statusCode == 403) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'JoyReactor access restricted or rate-limited (HTTP $statusCode)',
      );
    }

    final body = response.data ?? '';
    final effectiveUrl = response.realUri.toString().isNotEmpty &&
            response.realUri.host.isNotEmpty
        ? response.realUri.toString()
        : url;

    return _parser.parsePage(body, currentUrl: effectiveUrl);
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
