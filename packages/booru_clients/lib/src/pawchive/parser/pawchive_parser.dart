// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:html/parser.dart' as html_parser;

// Project imports:
import '../types/types.dart';

class PawchiveParser {
  const PawchiveParser({
    this.baseUrl = 'https://pawchive.pw',
    this.fileHostUrl = 'https://file.pawchive.pw',
    this.thumbnailHostUrl = 'https://img.pawchive.pw',
  });

  final String baseUrl;
  final String fileHostUrl;
  final String thumbnailHostUrl;

  static const Set<String> _kVideoExtensions = {
    'mp4',
    'webm',
    'mov',
    'm4v',
    'mkv',
  };

  static const Set<String> _kImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
    'avif',
  };

  static const Set<String> _kArchiveExtensions = {
    'zip',
    'rar',
    '7z',
    'psd',
    'clip',
    'pdf',
  };

  /// Parses a `/api/v1/posts`, `/api/v1/posts/popular`, or `/api/v1/<service>/user/<id>`
  /// JSON response into a [PawchivePageResultDto].
  PawchivePageResultDto parsePostsPage(
    dynamic rawData, {
    int offset = 0,
    Map<String, String> creatorNamesByKey = const {},
  }) {
    final decoded = _decodeJsonIfNeeded(rawData);
    if (decoded == null) {
      return PawchivePageResultDto(posts: const [], offset: offset);
    }

    List<dynamic> rawList = const [];
    int? count;
    int? trueCount;

    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map) {
      if (decoded['posts'] is List) {
        rawList = decoded['posts'] as List<dynamic>;
      } else if (decoded['results'] is List) {
        rawList = decoded['results'] as List<dynamic>;
      } else if (decoded['data'] is List) {
        rawList = decoded['data'] as List<dynamic>;
      }
      count = _parseInt(decoded['count']);
      trueCount = _parseInt(decoded['true_count']);
    }

    final posts = <PawchivePostDto>[];
    final seenPostKeys = <String>{};

    for (final item in rawList) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final post = parsePost(
          map,
          creatorNamesByKey: creatorNamesByKey,
        );
        if (post != null &&
            seenPostKeys.add('${post.service}:${post.userId}:${post.id}')) {
          posts.add(post);
        }
      }
    }

    return PawchivePageResultDto(
      posts: posts,
      offset: offset,
      count: count,
      trueCount: trueCount,
    );
  }

  /// Parses a single post JSON object (either direct post map or `{"post": {...}, "attachments": [...], "previews": [...]}` envelope).
  PawchivePostDto? parsePost(
    dynamic rawData, {
    Map<String, String> creatorNamesByKey = const {},
  }) {
    final decoded = _decodeJsonIfNeeded(rawData);
    if (decoded is! Map) return null;

    final rootMap = Map<String, dynamic>.from(decoded);
    final postMap = rootMap['post'] is Map
        ? Map<String, dynamic>.from(rootMap['post'] as Map)
        : rootMap;

    final id = (postMap['id'] ?? '').toString().trim();
    if (id.isEmpty) return null;

    final service = (postMap['service'] ?? 'patreon').toString().trim();
    final userId =
        (postMap['user'] ?? postMap['creator_id'] ?? 'unknown').toString().trim();
    final title = (postMap['title'] ?? '').toString().trim();

    // Resolve creator display name from `user_profile`, `username`, or cached creator directory
    String? username = postMap['username']?.toString().trim();
    if ((username == null || username.isEmpty) &&
        postMap['user_profile'] is Map) {
      final profile = postMap['user_profile'] as Map;
      username = (profile['name'] ?? profile['public_id'])?.toString().trim();
    }
    if ((username == null || username.isEmpty) &&
        rootMap['user_profile'] is Map) {
      final profile = rootMap['user_profile'] as Map;
      username = (profile['name'] ?? profile['public_id'])?.toString().trim();
    }
    username ??= creatorNamesByKey['$service:$userId'];

    final hasFull = postMap['has_full'] is bool
        ? postMap['has_full'] as bool
        : (postMap['preview_state']?.toString() != 'preview_only');
    final previewState = postMap['preview_state']?.toString();

    // Extract server map from envelope `previews` or `attachments` if provided separately
    final serverByPath = <String, String>{};
    for (final listKey in ['previews', 'attachments', 'videos']) {
      final envList = rootMap[listKey];
      if (envList is List) {
        for (final entry in envList) {
          if (entry is Map) {
            final p = entry['path']?.toString().trim();
            final s = entry['server']?.toString().trim();
            if (p != null && p.isNotEmpty && s != null && s.isNotEmpty) {
              serverByPath[p] = s;
            }
          }
        }
      }
    }

    // Collect and deduplicate `file` and `attachments`
    // (Prevents the duplicate main-file bug reported in gallery-dl #9878)
    final files = <PawchiveFileDto>[];
    final seenFileKeys = <String>{};

    void addCandidateFile(dynamic rawFile) {
      if (rawFile is! Map || rawFile.isEmpty) return;
      final fileMap = Map<String, dynamic>.from(rawFile);
      final dto = _parseFileEntry(
        fileMap,
        index: files.length,
        postHasFull: hasFull,
        serverByPath: serverByPath,
      );
      if (dto == null) return;

      final dedupKey = _canonicalFileKey(dto);
      if (seenFileKeys.add(dedupKey)) {
        files.add(dto);
      }
    }

    if (postMap['file'] is Map) {
      addCandidateFile(postMap['file']);
    }

    final rawAttachments = postMap['attachments'] ?? rootMap['attachments'];
    if (rawAttachments is List) {
      for (final att in rawAttachments) {
        addCandidateFile(att);
      }
    }

    // Also inspect inline HTML `content` for embedded `<img src="...">` if no files were attached
    final rawContent = (postMap['content'] ?? '').toString();
    if (files.isEmpty && rawContent.contains('<img')) {
      final doc = html_parser.parseFragment(rawContent);
      for (final img in doc.querySelectorAll('img')) {
        final src = (img.attributes['data-src'] ?? img.attributes['src'] ?? '')
            .trim();
        if (src.isEmpty || src.contains('avatar')) continue;
        final inlineDto = _parseInlineHtmlImage(src, index: files.length);
        if (inlineDto != null &&
            seenFileKeys.add(_canonicalFileKey(inlineDto))) {
          files.add(inlineDto);
        }
      }
    }

    if (files.isEmpty) return null;

    // Extract tags and synthesize service/creator tags for Boorusama tag chips
    final tags = <String>[];
    final seenTags = <String>{};

    void addTag(String rawTag) {
      final cleaned = rawTag
          .trim()
          .replaceAll(RegExp(r'^#+'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      if (cleaned.isEmpty) return;
      if (seenTags.add(cleaned.toLowerCase())) {
        tags.add(cleaned);
      }
    }

    addTag(service);
    if (username != null && username.isNotEmpty) {
      addTag('artist:${username.replaceAll(RegExp(r'\s+'), '_')}');
    }
    addTag('$service:user:$userId');

    final rawTags = postMap['tags'];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null) addTag(t.toString());
      }
    } else if (rawTags is String && rawTags.trim().isNotEmpty) {
      final trimmedTags = rawTags.trim();
      if (trimmedTags.startsWith('{') && trimmedTags.endsWith('}')) {
        for (final part
            in trimmedTags.substring(1, trimmedTags.length - 1).split(',')) {
          addTag(part.replaceAll('"', ''));
        }
      } else {
        for (final part in trimmedTags.split(RegExp(r'[,;\s]+'))) {
          addTag(part);
        }
      }
    }

    final publishedAt = _parseTimestamp(
      postMap['published'],
      service: service,
    );
    final addedAt = _parseTimestamp(postMap['added'], service: service);
    final editedAt = _parseTimestamp(postMap['edited'], service: service);

    final cleanContent = _stripHtmlContent(rawContent);
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final postUrl = '$cleanBase/$service/user/$userId/post/$id';

    return PawchivePostDto(
      id: id,
      service: service,
      userId: userId,
      username: username,
      title: title,
      postUrl: postUrl,
      files: files,
      tags: tags,
      content: cleanContent,
      publishedAt: publishedAt,
      addedAt: addedAt,
      editedAt: editedAt,
      hasFull: hasFull,
      previewState: previewState,
    );
  }

  /// Parses creator directory JSON from `/api/v1/creators` or `/api/v1/creators.txt`.
  List<PawchiveCreatorDto> parseCreators(dynamic rawData) {
    final decoded = _decodeJsonIfNeeded(rawData);
    if (decoded is! List) return const [];

    final creators = <PawchiveCreatorDto>[];
    for (final item in decoded) {
      if (item is Map) {
        final id = (item['id'] ?? '').toString().trim();
        final name = (item['name'] ?? '').toString().trim();
        final service = (item['service'] ?? '').toString().trim();
        if (id.isEmpty || name.isEmpty || service.isEmpty) continue;

        creators.add(
          PawchiveCreatorDto(
            id: id,
            name: name,
            service: service,
            publicId: item['public_id']?.toString(),
            everImported: item['ever_imported'] is bool
                ? item['ever_imported'] as bool
                : true,
            favorited: _parseInt(item['favorited']),
            indexed: _parseTimestamp(item['indexed']),
            updated: _parseTimestamp(item['updated']),
          ),
        );
      }
    }
    return creators;
  }

  /// Parses tags list from `/api/v1/posts/tags` or tag autocomplete JSON.
  List<PawchiveTagDto> parseTags(dynamic rawData) {
    final decoded = _decodeJsonIfNeeded(rawData);
    final List<dynamic> list = decoded is List
        ? decoded
        : (decoded is Map && decoded['tags'] is List
            ? decoded['tags'] as List<dynamic>
            : const []);

    final results = <PawchiveTagDto>[];
    for (final item in list) {
      if (item is String && item.trim().isNotEmpty) {
        results.add(PawchiveTagDto(name: item.trim()));
      } else if (item is Map) {
        final name = (item['tag'] ?? item['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        results.add(
          PawchiveTagDto(
            name: name,
            count: _parseInt(item['post_count'] ?? item['count']),
          ),
        );
      }
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // Internal File & URL Resolution Helpers
  // ---------------------------------------------------------------------------

  PawchiveFileDto? _parseFileEntry(
    Map<String, dynamic> fileMap, {
    required int index,
    required bool postHasFull,
    required Map<String, String> serverByPath,
  }) {
    final rawPath = (fileMap['path'] ?? '').toString().trim();
    final rawUrl = (fileMap['url'] ?? '').toString().trim();
    final tempUrl = (fileMap['temp_url'] ?? '').toString().trim();
    final rawName =
        (fileMap['name'] ?? fileMap['filename'] ?? '').toString().trim();
    final isDeferred = fileMap['deferred'] == true;
    final isPreviewOnly = fileMap['preview_only'] == true || !postHasFull;

    // If a deferred file has neither path, url, nor temp_url, skip it cleanly (gallery-dl #9768)
    if (rawPath.isEmpty && rawUrl.isEmpty && tempUrl.isEmpty) {
      return null;
    }

    // Normalize relative `/data/...` vs `/136/e8/...`
    String cleanDataSubpath = '';
    if (rawPath.isNotEmpty) {
      cleanDataSubpath = rawPath.startsWith('/data/')
          ? rawPath.substring(5)
          : (rawPath.startsWith('/') ? rawPath : '/$rawPath');
    } else if (rawUrl.contains('/data/')) {
      cleanDataSubpath = '/${rawUrl.split('/data/').last.split('?').first}';
    }

    final ext = _resolveExtension(
      explicitExt: fileMap['extension']?.toString(),
      name: rawName,
      path: cleanDataSubpath.isNotEmpty ? cleanDataSubpath : (tempUrl.isNotEmpty ? tempUrl : rawUrl),
    );

    final mediaType = _classifyExtension(ext);
    // Skip non-visual archive attachments (.zip, .7z, .rar) in Boorusama's image/video grid
    if (mediaType == PawchiveMediaType.archive) {
      return null;
    }

    final server =
        (fileMap['server']?.toString().trim().isNotEmpty == true)
            ? fileMap['server'].toString().trim()
            : (serverByPath[rawPath] ?? fileHostUrl);
    final cleanServer = server.endsWith('/')
        ? server.substring(0, server.length - 1)
        : server;
    final cleanThumbHost = thumbnailHostUrl.endsWith('/')
        ? thumbnailHostUrl.substring(0, thumbnailHostUrl.length - 1)
        : thumbnailHostUrl;

    // Construct thumbnail URL (`https://img.pawchive.pw/thumbnail/data/<subpath>`)
    String thumbnailUrl;
    if (cleanDataSubpath.isNotEmpty) {
      thumbnailUrl = '$cleanThumbHost/thumbnail/data$cleanDataSubpath';
    } else if (rawUrl.isNotEmpty) {
      thumbnailUrl = toThumbnailUrl(rawUrl);
    } else {
      thumbnailUrl = tempUrl;
    }

    // Construct full-resolution URL (`temp_url` signed `/f/` link, explicit `url`, or `<server>/data/<subpath>`)
    // As fixed in gallery-dl #9853 / #9727:
    // - If `temp_url` is present, prefer `temp_url` (preserving `?e=...&s=...` query signature).
    // - If `isPreviewOnly` is true and no `temp_url` exists, fall back to `thumbnailUrl` so 404s are avoided.
    String originalUrl;
    if (tempUrl.isNotEmpty) {
      originalUrl = _normalizeFullUrl(tempUrl);
    } else if (isPreviewOnly && mediaType == PawchiveMediaType.image) {
      originalUrl = thumbnailUrl;
    } else if (rawUrl.isNotEmpty) {
      originalUrl = _normalizeFullUrl(rawUrl);
    } else {
      originalUrl = '$cleanServer/data$cleanDataSubpath';
    }

    // For video files, thumbnail on grid uses the static preview or video URL
    final sampleUrl = mediaType == PawchiveMediaType.video
        ? originalUrl
        : (isPreviewOnly ? thumbnailUrl : originalUrl);

    final resolvedName = rawName.isNotEmpty
        ? (rawName.contains('.') ? rawName : '$rawName.$ext')
        : _extractFilenameFromPath(cleanDataSubpath.isNotEmpty ? cleanDataSubpath : originalUrl, index, ext);

    final hash = _extractHash(fileMap['hash']?.toString(), cleanDataSubpath);

    return PawchiveFileDto(
      index: index,
      name: resolvedName,
      path: cleanDataSubpath.isNotEmpty ? cleanDataSubpath : originalUrl,
      thumbnailUrl: thumbnailUrl,
      sampleUrl: sampleUrl,
      originalUrl: originalUrl,
      type: mediaType,
      extension: ext,
      server: cleanServer,
      tempUrl: tempUrl.isNotEmpty ? tempUrl : null,
      isPreviewOnly: isPreviewOnly && tempUrl.isEmpty,
      isDeferred: isDeferred,
      hash: hash,
    );
  }

  PawchiveFileDto? _parseInlineHtmlImage(String src, {required int index}) {
    final normalized = _normalizeFullUrl(src);
    final ext = _resolveExtension(path: normalized);
    final mediaType = _classifyExtension(ext);
    if (mediaType == PawchiveMediaType.archive) return null;

    final thumb = toThumbnailUrl(normalized);
    final full = toFullResUrl(normalized);
    final name = _extractFilenameFromPath(full, index, ext);

    return PawchiveFileDto(
      index: index,
      name: name,
      path: full,
      thumbnailUrl: thumb,
      sampleUrl: full,
      originalUrl: full,
      type: mediaType,
      extension: ext,
    );
  }

  /// Converts a Pawchive `/data/` URL into its `img.pawchive.pw/thumbnail/data/` counterpart.
  String toThumbnailUrl(String url) {
    final clean = url.split('?').first.trim();
    if (clean.contains('/thumbnail/data/')) return clean;
    if (clean.contains('pawchive.pw/data/')) {
      final cleanThumbHost = thumbnailHostUrl.endsWith('/')
          ? thumbnailHostUrl.substring(0, thumbnailHostUrl.length - 1)
          : thumbnailHostUrl;
      return clean.replaceFirst(
        RegExp(r'https?://[^/]+/data/'),
        '$cleanThumbHost/thumbnail/data/',
      );
    }
    return clean;
  }

  /// Converts a Pawchive `img.pawchive.pw/thumbnail/data/` URL into its `file.pawchive.pw/data/` full-resolution counterpart.
  String toFullResUrl(String url) {
    if (url.contains('pawchive.pw/f/')) return url.trim();
    final clean = url.split('?').first.trim();
    final cleanFileHost = fileHostUrl.endsWith('/')
        ? fileHostUrl.substring(0, fileHostUrl.length - 1)
        : fileHostUrl;
    if (clean.contains('img.pawchive.pw/thumbnail/data/')) {
      return clean.replaceFirst(
        'https://img.pawchive.pw/thumbnail/data/',
        '$cleanFileHost/data/',
      );
    }
    if (clean.contains('/thumbnail/data/')) {
      return clean.replaceFirst('/thumbnail/data/', '/data/');
    }
    return clean;
  }

  String _normalizeFullUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    final cleanFileHost = fileHostUrl.endsWith('/')
        ? fileHostUrl.substring(0, fileHostUrl.length - 1)
        : fileHostUrl;
    if (trimmed.startsWith('/data/')) {
      return '$cleanFileHost$trimmed';
    }
    if (trimmed.startsWith('/')) {
      return '$cleanFileHost/data$trimmed';
    }
    return '$cleanFileHost/data/$trimmed';
  }

  static String _canonicalFileKey(PawchiveFileDto dto) {
    if (dto.hash != null && dto.hash!.isNotEmpty) {
      return dto.hash!;
    }
    return dto.path
        .replaceFirst(RegExp(r'^https?://[^/]+'), '')
        .replaceFirst('/thumbnail', '')
        .split('?')
        .first;
  }

  static String _resolveExtension({
    String? explicitExt,
    String? name,
    String? path,
  }) {
    for (final candidate in [explicitExt, name, path]) {
      if (candidate == null || candidate.trim().isEmpty) continue;
      final clean = candidate.split('?').first.trim();
      final dotIdx = clean.lastIndexOf('.');
      if (dotIdx != -1 && dotIdx < clean.length - 1) {
        final ext = clean.substring(dotIdx + 1).toLowerCase();
        if (ext.length <= 5 && !ext.contains('/')) {
          return ext;
        }
      } else if (candidate == explicitExt) {
        final ext = clean.replaceFirst('.', '').toLowerCase();
        if (ext.isNotEmpty && ext.length <= 5) return ext;
      }
    }
    return 'jpg';
  }

  static PawchiveMediaType _classifyExtension(String ext) {
    final lower = ext.toLowerCase();
    if (lower == 'gif') return PawchiveMediaType.gif;
    if (_kVideoExtensions.contains(lower)) return PawchiveMediaType.video;
    if (_kArchiveExtensions.contains(lower)) return PawchiveMediaType.archive;
    if (_kImageExtensions.contains(lower)) return PawchiveMediaType.image;
    return PawchiveMediaType.image;
  }

  static String _extractFilenameFromPath(
    String pathOrUrl,
    int index,
    String ext,
  ) {
    final fMatch = RegExp(r'[?&]f=([^&]+)').firstMatch(pathOrUrl);
    if (fMatch != null && fMatch.group(1) != null) {
      final decoded = Uri.decodeComponent(fMatch.group(1)!);
      if (decoded.isNotEmpty) return decoded;
    }
    final clean = pathOrUrl.split('?').first;
    final lastSlash = clean.lastIndexOf('/');
    final segment = lastSlash != -1 ? clean.substring(lastSlash + 1) : clean;
    if (segment.isNotEmpty) return segment;
    return 'image_$index.$ext';
  }

  static String? _extractHash(String? explicitHash, String subpath) {
    if (explicitHash != null && explicitHash.trim().isNotEmpty) {
      return explicitHash.trim();
    }
    final match = RegExp(r'([a-fA-F0-9]{32,64})').firstMatch(subpath);
    return match?.group(1)?.toLowerCase();
  }

  static DateTime? _parseTimestamp(dynamic raw, {String? service}) {
    if (raw == null) return null;
    if (raw is int) {
      final ms = raw < 10000000000 ? raw * 1000 : raw;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    // As documented in KToolBox v1.1.0 (#390), Fanbox timestamps without a timezone offset
    // represent Asia/Tokyo (+09:00), whereas Patreon defaults to UTC.
    final hasExplicitZone = str.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(str);
    final normalizedIso = hasExplicitZone
        ? str
        : (service == 'fanbox' ? '$str+09:00' : '${str}Z');

    return DateTime.tryParse(normalizedIso)?.toUtc() ??
        DateTime.tryParse(str)?.toUtc();
  }

  static String? _stripHtmlContent(String rawHtml) {
    if (rawHtml.trim().isEmpty) return null;
    if (!rawHtml.contains('<')) return rawHtml.trim();
    final fragment = html_parser.parseFragment(rawHtml);
    final text = (fragment.text ?? '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return text.isEmpty ? null : text;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value != null) return int.tryParse(value.toString());
    return null;
  }

  static dynamic _decodeJsonIfNeeded(dynamic rawData) {
    if (rawData == null) return null;
    if (rawData is Map || rawData is List) return rawData;
    if (rawData is String) {
      final trimmed = rawData.trim();
      if (trimmed.isEmpty) return null;
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
