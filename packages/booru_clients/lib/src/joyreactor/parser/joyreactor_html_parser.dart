// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

// Project imports:
import '../types/types.dart';

class JoyreactorHtmlParser {
  const JoyreactorHtmlParser({
    this.baseUrl = 'https://joyreactor.com',
  });

  final String baseUrl;

  static const Set<String> _kNsfwTagMarkers = {
    'эротика',
    'erotica',
    'nsfw',
    '18+',
    'порно',
    'porn',
    'hentai',
    'хентай',
    'ecchi',
    'эччи',
    'r34',
    'rule34',
  };

  /// Parses a full JoyReactor HTML listing or single-post page into [JoyreactorPageResultDto].
  JoyreactorPageResultDto parsePage(
    String htmlContent, {
    String? currentUrl,
  }) {
    final resolvedCurrentUrl = currentUrl ?? baseUrl;
    if (htmlContent.trim().isEmpty) {
      return JoyreactorPageResultDto(
        posts: const [],
        currentUrl: resolvedCurrentUrl,
      );
    }

    final document = html_parser.parse(htmlContent);
    final posts = <JoyreactorPostDto>[];
    final seenPostIds = <int>{};

    // JoyReactor wraps posts in `.postContainer` or `.uhead` + `.ufoot` blocks.
    final postElements = document.querySelectorAll(
      'div.postContainer, div.article.post-normal, div[id^="postContainer"], div.content',
    );

    if (postElements.isNotEmpty) {
      for (final element in postElements) {
        final post = parsePostElement(element);
        if (post != null && seenPostIds.add(post.id)) {
          posts.add(post);
        }
      }
    } else {
      // Fallback: if `.postContainer` wrapper is absent (e.g. single post view or older markup),
      // locate `.uhead` elements and group siblings up to `.ufoot`.
      final uheads = document.querySelectorAll('div.uhead');
      for (final uhead in uheads) {
        final parent = uhead.parent;
        if (parent != null) {
          final post = parsePostElement(parent);
          if (post != null && seenPostIds.add(post.id)) {
            posts.add(post);
          }
        }
      }
    }

    final pagination = _parsePagination(document);

    return JoyreactorPageResultDto(
      posts: posts,
      currentUrl: resolvedCurrentUrl,
      currentPageNumber: pagination.currentPageNumber,
      nextPageUrl: pagination.nextPageUrl,
      prevPageUrl: pagination.prevPageUrl,
    );
  }

  /// Parses an individual post container DOM [element] into a [JoyreactorPostDto].
  JoyreactorPostDto? parsePostElement(dom.Element element) {
    final jsonLd = _extractJsonLd(element);

    // 1. Extract Post ID & URL
    int? postId = _extractPostId(element, jsonLd);
    if (postId == null || postId <= 0) return null;

    final postUrl = normalizeUrl('/post/$postId');

    // 2. Extract Tags (DOM `.taglist a` + JSON-LD fallback)
    final tags = _extractTags(element, jsonLd);

    // 3. Extract Author information
    final authorInfo = _extractAuthor(element, jsonLd);

    // 4. Extract Post Timestamp
    final createdAt = _extractTimestamp(element, jsonLd);

    // 5. Extract Post Score
    final score = _extractScore(element);

    // 6. Extract Comment count
    final commentCount = _extractCommentCount(element);

    // 7. Extract Title & Description
    final titleAndDesc = _extractTitleAndDescription(element, jsonLd);

    // 8. Extract Media Attachments
    final media = _extractMediaAttachments(element);
    if (media.isEmpty) {
      // Skip text-only posts that have no visual media or embedded content
      return null;
    }

    // 9. Determine NSFW status
    final isNsfw = _detectNsfw(element, tags);

    return JoyreactorPostDto(
      id: postId,
      postUrl: postUrl,
      tags: tags,
      media: media,
      authorName: authorInfo.name,
      authorId: authorInfo.id,
      authorAvatarUrl: authorInfo.avatarUrl,
      createdAt: createdAt,
      score: score,
      commentCount: commentCount,
      title: titleAndDesc.title,
      description: titleAndDesc.description,
      isNsfw: isNsfw,
    );
  }

  /// Parses tag autocomplete/search suggestions from JoyReactor HTML or JSON response.
  List<JoyreactorTagDto> parseTagSuggestions(String responseBody) {
    if (responseBody.trim().isEmpty) return const [];

    // Try JSON array or object first (if returned by AJAX autocomplete endpoint)
    final trimmed = responseBody.trim();
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map((item) {
                if (item is String) {
                  final clean = unescapeHtml(item).trim();
                  return JoyreactorTagDto(
                    name: clean,
                    url: normalizeUrl('/tag/${encodeTagForPath(clean)}'),
                  );
                } else if (item is Map) {
                  final rawName =
                      (item['name'] ?? item['value'] ?? item['label'] ?? '')
                          .toString();
                  final clean = unescapeHtml(rawName).trim();
                  final count = item['count'] is int
                      ? item['count'] as int
                      : int.tryParse('${item['count'] ?? ''}');
                  return JoyreactorTagDto(
                    name: clean,
                    url: normalizeUrl('/tag/${encodeTagForPath(clean)}'),
                    count: count,
                  );
                }
                return null;
              })
              .whereType<JoyreactorTagDto>()
              .where((t) => t.name.isNotEmpty)
              .toList();
        }
      } catch (_) {
        // Fall through to line/HTML parsing
      }
    }

    // Parse HTML document for `.taglist a` or search result tag links
    if (trimmed.contains('<')) {
      final doc = html_parser.parse(trimmed);
      final tagAnchors = doc.querySelectorAll(
        '.taglist a, .search_results_tags a, a[href*="/tag/"]',
      );
      final seen = <String>{};
      final results = <JoyreactorTagDto>[];
      for (final a in tagAnchors) {
        final name = unescapeHtml(a.text).trim();
        final href = a.attributes['href'] ?? '';
        if (name.isNotEmpty && seen.add(name.toLowerCase())) {
          results.add(
            JoyreactorTagDto(
              name: name,
              url: href.isNotEmpty
                  ? normalizeUrl(href)
                  : normalizeUrl('/tag/${encodeTagForPath(name)}'),
            ),
          );
        }
      }
      if (results.isNotEmpty) return results;
    }

    // Plain-text newline-delimited autocomplete format
    return trimmed
        .split(RegExp(r'\r?\n'))
        .map((line) => unescapeHtml(line.split('|').first).trim())
        .where((name) => name.isNotEmpty)
        .map(
          (name) => JoyreactorTagDto(
            name: name,
            url: normalizeUrl('/tag/${encodeTagForPath(name)}'),
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Internal Extraction Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _extractJsonLd(dom.Element element) {
    final scripts = element.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
      var raw = script.text.trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // JoyReactor JSON-LD occasionally contains unescaped control characters (< 0x20)
        // or unescaped backslashes, as documented in gallery-dl's reactor.py.
        try {
          final sanitized = raw
              .replaceAll(RegExp(r'[\x00-\x1F]'), ' ')
              .replaceAll(r'\', r'\\');
          final decoded = jsonDecode(sanitized);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {
          // Ignore malformed JSON-LD and rely on HTML DOM selectors
        }
      }
    }
    return null;
  }

  int? _extractPostId(dom.Element element, Map<String, dynamic>? jsonLd) {
    // 1. Check container id="postContainer5061838"
    final elemId = element.id;
    if (elemId.isNotEmpty) {
      final match = RegExp(r'(\d+)$').firstMatch(elemId);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null) return parsed;
      }
    }

    // 2. Check inner `.post_content` id="post_content_5061838" or `.post_rating` id="post_rating_5061838"
    for (final selector in [
      '[id^="postContainer"]',
      '[id^="post_content_"]',
      '[id^="post_rating_"]',
      '[id^="post_status_"]',
    ]) {
      final sub = element.querySelector(selector);
      if (sub != null) {
        final match = RegExp(r'(\d+)$').firstMatch(sub.id);
        if (match != null) {
          final parsed = int.tryParse(match.group(1)!);
          if (parsed != null) return parsed;
        }
      }
    }

    // 3. Check permalink anchor `<a href="/post/5061838" class="link">`
    final linkAnchors = element.querySelectorAll('a[href*="/post/"]');
    for (final a in linkAnchors) {
      final href = a.attributes['href'] ?? '';
      final match = RegExp(r'/post/(\d+)').firstMatch(href);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null) return parsed;
      }
    }

    // 4. Fallback to JSON-LD `mainEntityOfPage.@id`
    if (jsonLd != null) {
      final mainEntity = jsonLd['mainEntityOfPage'];
      final entityId = mainEntity is Map ? mainEntity['@id']?.toString() : null;
      if (entityId != null) {
        final match = RegExp(r'/post/(\d+)').firstMatch(entityId);
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
      }
    }

    return null;
  }

  List<JoyreactorTagDto> _extractTags(
    dom.Element element,
    Map<String, dynamic>? jsonLd,
  ) {
    final results = <JoyreactorTagDto>[];
    final seenNames = <String>{};

    // 1. Primary DOM `.taglist a` elements
    final tagAnchors = element.querySelectorAll('.taglist a, h2.taglist a, .post-tags a');
    for (final a in tagAnchors) {
      final rawText = a.text.trim().isNotEmpty
          ? a.text
          : (a.attributes['title'] ?? '');
      final name = unescapeHtml(rawText).trim();
      if (name.isEmpty) continue;

      final key = name.toLowerCase();
      if (seenNames.add(key)) {
        final href = a.attributes['href'] ?? '';
        results.add(
          JoyreactorTagDto(
            name: name,
            url: href.isNotEmpty
                ? normalizeUrl(href)
                : normalizeUrl('/tag/${encodeTagForPath(name)}'),
          ),
        );
      }
    }

    // 2. Fallback / supplement from JSON-LD `headline` ("Title / Tag1 :: Tag2 :: Tag3")
    if (results.isEmpty && jsonLd != null && jsonLd['headline'] is String) {
      final headline = unescapeHtml(jsonLd['headline'] as String).trim();
      final parts = headline.split(' / ');
      final tagPart = parts.length > 1 ? parts.sublist(1).join(' / ') : headline;
      for (final rawTag in tagPart.split(' :: ')) {
        final clean = rawTag.trim();
        if (clean.isEmpty) continue;
        if (seenNames.add(clean.toLowerCase())) {
          results.add(
            JoyreactorTagDto(
              name: clean,
              url: normalizeUrl('/tag/${encodeTagForPath(clean)}'),
            ),
          );
        }
      }
    }

    return results;
  }

  ({String? name, int? id, String? avatarUrl}) _extractAuthor(
    dom.Element element,
    Map<String, dynamic>? jsonLd,
  ) {
    String? name;
    int? userId;
    String? avatarUrl;

    final userAnchor = element.querySelector(
      '.uhead_nick a[href*="/user/"], .uhead_nick a',
    );
    if (userAnchor != null) {
      final text = unescapeHtml(userAnchor.text).trim();
      if (text.isNotEmpty) {
        name = text;
      }
    }

    final avatarImg = element.querySelector(
      '.uhead_nick img.avatar, .uhead img, img[src*="/avatar/user/"]',
    );
    if (avatarImg != null) {
      final src = avatarImg.attributes['src'];
      if (src != null && src.isNotEmpty) {
        avatarUrl = normalizeUrl(src);
      }
      final idClass = avatarImg.className;
      final idMatch = RegExp(r'user_(\d+)').firstMatch(idClass) ??
          RegExp(r'/avatar/user/(\d+)').firstMatch(src);
      if (idMatch != null) {
        userId = int.tryParse(idMatch.group(1)!);
      }
    }

    if (name == null || name.isEmpty) {
      final avatarAlt = element
          .querySelector('img[src*="/avatar/user/"][alt], img.avatar[alt]')
          ?.attributes['alt'];
      final fallbackName = unescapeHtml(avatarAlt ?? '').trim();
      if (fallbackName.isNotEmpty) name = fallbackName;
    }

    if ((name == null || name.isEmpty) && jsonLd != null) {
      final author = jsonLd['author'];
      if (author is Map && author['name'] is String) {
        final ldName = unescapeHtml(author['name'] as String).trim();
        if (ldName.isNotEmpty) {
          name = ldName;
        }
      }
    }

    return (name: name, id: userId, avatarUrl: avatarUrl);
  }

  DateTime? _extractTimestamp(
    dom.Element element,
    Map<String, dynamic>? jsonLd,
  ) {
    // 1. Check `<span data-time="1710512400">` unix epoch attribute
    final timeSpan = element.querySelector(
      '.uhead_share span[data-time], span.date span[data-time], [data-time]',
    );
    if (timeSpan != null) {
      final rawEpoch = timeSpan.attributes['data-time']?.trim() ?? '';
      final epochVal = int.tryParse(rawEpoch);
      if (epochVal != null && epochVal > 0) {
        // Handle both seconds and milliseconds epoch
        final ms = epochVal < 10000000000 ? epochVal * 1000 : epochVal;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      }
    }

    // 2. Check `<time datetime="...">`
    final timeElem = element.querySelector('time[datetime]');
    if (timeElem != null) {
      final dtStr = timeElem.attributes['datetime']?.trim() ?? '';
      final parsed = DateTime.tryParse(dtStr);
      if (parsed != null) return parsed.toUtc();
    }

    // 3. Check JSON-LD `datePublished`
    if (jsonLd != null && jsonLd['datePublished'] is String) {
      final parsed = DateTime.tryParse(jsonLd['datePublished'] as String);
      if (parsed != null) return parsed.toUtc();
    }

    return null;
  }

  double? _extractScore(dom.Element element) {
    final ratingSpan = element.querySelector(
      '.ufoot .post_rating, span.post_rating, [id^="post_rating_"]',
    );
    if (ratingSpan == null) return null;

    final rawText = unescapeHtml(ratingSpan.text).trim();
    if (rawText.isEmpty || rawText == '--' || rawText == '—') {
      return null;
    }

    // Extract first signed floating-point or integer number (e.g. "42.5", "-3.2", "108")
    final match = RegExp(r'[-+]?\d+(?:[.,]\d+)?').firstMatch(rawText);
    if (match != null) {
      return double.tryParse(match.group(0)!.replaceAll(',', '.'));
    }
    return null;
  }

  int? _extractCommentCount(dom.Element element) {
    final commentLink = element.querySelector(
      '.ufoot a.commentnum, a[href*="#comment"]',
    );
    if (commentLink == null) return null;

    final rawText = unescapeHtml(commentLink.text).trim();
    final match = RegExp(r'(\d+)').firstMatch(rawText);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  ({String? title, String? description}) _extractTitleAndDescription(
    dom.Element element,
    Map<String, dynamic>? jsonLd,
  ) {
    String? title;
    String? description;

    final postContent = element.querySelector('.post-content, .post_content');
    if (postContent != null) {
      final h3 = postContent.querySelector('h3, .post_title');
      if (h3 != null) {
        final t = unescapeHtml(h3.text).trim();
        if (t.isNotEmpty) title = t;
      }

      // Collect non-image text paragraphs if present
      final paragraphs = postContent
          .querySelectorAll('p, div.post_description')
          .map((p) => unescapeHtml(p.text).trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (paragraphs.isNotEmpty) {
        description = paragraphs.join('\n\n');
      }
    }

    if (jsonLd != null) {
      if ((title == null || title.isEmpty) && jsonLd['headline'] is String) {
        final headline = unescapeHtml(jsonLd['headline'] as String).trim();
        final firstPart = headline.split(' / ').first.trim();
        if (firstPart.isNotEmpty) title = firstPart;
      }
      if ((description == null || description.isEmpty) &&
          jsonLd['description'] is String) {
        final ldDesc = unescapeHtml(jsonLd['description'] as String).trim();
        if (ldDesc.isNotEmpty) description = ldDesc;
      }
    }

    return (title: title, description: description);
  }

  List<JoyreactorMediaDto> _extractMediaAttachments(dom.Element element) {
    final postContent =
        element.querySelector('.post-content, .post_content') ?? element;
    final imageContainers = postContent.querySelectorAll('div.image');

    final attachments = <JoyreactorMediaDto>[];
    final seenUrls = <String>{};

    void addMedia(JoyreactorMediaDto? media) {
      if (media != null && seenUrls.add(media.originalUrl)) {
        attachments.add(media);
      }
    }

    if (imageContainers.isNotEmpty) {
      // Legacy layout: each attachment is wrapped in a div.image.
      for (final container in imageContainers) {
        addMedia(
          _parseSingleMediaContainer(
            container,
            index: attachments.length,
          ),
        );
      }
    } else {
      // Current layout: media may be placed directly inside .post-content.
      for (final video in postContent.querySelectorAll('video')) {
        addMedia(
          _parseVideoElement(
            container: video.parent ?? postContent,
            videoElem: video,
            index: attachments.length,
          ),
        );
      }

      for (final img in postContent.querySelectorAll('img')) {
        final rawSrc =
            (img.attributes['src'] ?? img.attributes['data-src'] ?? '').trim();
        if (rawSrc.isEmpty || rawSrc.contains('/avatar/')) continue;
        if (img.classes.contains('avatar')) continue;
        addMedia(
          _parseImageElement(
            container: img.parent ?? postContent,
            imgElem: img,
            index: attachments.length,
          ),
        );
      }

      for (final iframe in postContent.querySelectorAll('iframe')) {
        final rawSrc = iframe.attributes['src']?.trim() ?? '';
        if (rawSrc.isEmpty) continue;
        final embedUrl = normalizeUrl(rawSrc);
        addMedia(
          JoyreactorMediaDto(
            index: attachments.length,
            thumbnailUrl: embedUrl,
            sampleUrl: embedUrl,
            originalUrl: embedUrl,
            type: JoyreactorMediaType.embed,
            width: int.tryParse(iframe.attributes['width'] ?? ''),
            height: int.tryParse(iframe.attributes['height'] ?? ''),
            format: 'embed',
          ),
        );
      }
    }

    return attachments;
  }

  JoyreactorMediaDto? _parseSingleMediaContainer(
    dom.Element container, {
    required int index,
  }) {
    // 1. Check for <video> (animated GIF / WebM / MP4)
    final videoElem = container.querySelector('video');
    if (videoElem != null) {
      return _parseVideoElement(
        container: container,
        videoElem: videoElem,
        index: index,
      );
    }

    // 2. Check for static/animated <img>
    final imgElem = container.querySelector('img');
    if (imgElem != null) {
      return _parseImageElement(
        container: container,
        imgElem: imgElem,
        index: index,
      );
    }

    // 3. Check for external <iframe> embed (Coub, YouTube, Vimeo) so unsupported media is not silently discarded
    final iframeElem = container.querySelector('iframe');
    if (iframeElem != null) {
      final rawSrc = iframeElem.attributes['src']?.trim() ?? '';
      if (rawSrc.isNotEmpty) {
        final embedUrl = normalizeUrl(rawSrc);
        final width = int.tryParse(iframeElem.attributes['width'] ?? '');
        final height = int.tryParse(iframeElem.attributes['height'] ?? '');
        return JoyreactorMediaDto(
          index: index,
          thumbnailUrl: embedUrl,
          sampleUrl: embedUrl,
          originalUrl: embedUrl,
          type: JoyreactorMediaType.embed,
          width: width,
          height: height,
          format: 'embed',
        );
      }
    }

    return null;
  }

  JoyreactorMediaDto? _parseVideoElement({
    required dom.Element container,
    required dom.Element videoElem,
    required int index,
  }) {
    String? mp4Url;
    String? webmUrl;
    String? gifUrl;

    for (final source in videoElem.querySelectorAll('source')) {
      final src = source.attributes['src']?.trim() ?? '';
      if (src.isEmpty) continue;
      final normalized = normalizeUrl(src);
      final typeAttr = (source.attributes['type'] ?? '').toLowerCase();
      if (typeAttr.contains('mp4') || normalized.toLowerCase().endsWith('.mp4')) {
        mp4Url ??= normalized;
      } else if (typeAttr.contains('webm') ||
          normalized.toLowerCase().endsWith('.webm')) {
        webmUrl ??= normalized;
      }
    }

    final directVideoSrc = videoElem.attributes['src']?.trim() ?? '';
    if (directVideoSrc.isNotEmpty) {
      final normalized = normalizeUrl(directVideoSrc);
      if (normalized.toLowerCase().endsWith('.mp4')) {
        mp4Url ??= normalized;
      } else if (normalized.toLowerCase().endsWith('.webm')) {
        webmUrl ??= normalized;
      }
    }

    // Check for `a.video_gif_source` or `<a href="...gif">`
    final gifAnchor = container.querySelector(
      'a.video_gif_source, a[href*="/pics/post/full/"], a[href\$=".gif"]',
    );
    if (gifAnchor != null) {
      final href = gifAnchor.attributes['href']?.trim() ?? '';
      if (href.isNotEmpty) {
        final normalized = normalizeUrl(href);
        if (normalized.toLowerCase().endsWith('.gif')) {
          gifUrl = normalized;
        } else if (normalized.toLowerCase().endsWith('.mp4')) {
          mp4Url ??= normalized;
        } else if (normalized.toLowerCase().endsWith('.webm')) {
          webmUrl ??= normalized;
        }
      }
    }

    final videoStreamUrl = mp4Url ?? webmUrl;
    if (videoStreamUrl == null && gifUrl == null) return null;

    // Poster / thumbnail URL
    String? posterUrl = videoElem.attributes['poster']?.trim();
    if (posterUrl == null || posterUrl.isEmpty) {
      final imgFallback = container.querySelector('img');
      posterUrl = imgFallback?.attributes['src']?.trim();
    }

    final resolvedThumbnail = (posterUrl != null && posterUrl.isNotEmpty)
        ? normalizeUrl(posterUrl)
        : _deriveStaticPreviewFromMediaUrl(videoStreamUrl ?? gifUrl!);

    final width = int.tryParse(
      videoElem.attributes['width'] ??
          container.querySelector('img')?.attributes['width'] ??
          '',
    );
    final height = int.tryParse(
      videoElem.attributes['height'] ??
          container.querySelector('img')?.attributes['height'] ??
          '',
    );

    final primaryUrl = videoStreamUrl ?? gifUrl!;
    final ext = _extractExtension(primaryUrl) ?? (mp4Url != null ? 'mp4' : 'webm');
    final imageId = _extractAttachmentId(primaryUrl);

    return JoyreactorMediaDto(
      index: index,
      thumbnailUrl: resolvedThumbnail,
      sampleUrl: gifUrl ?? resolvedThumbnail,
      originalUrl: gifUrl ?? primaryUrl,
      type: videoStreamUrl != null
          ? JoyreactorMediaType.video
          : JoyreactorMediaType.gif,
      videoUrl: videoStreamUrl,
      mp4Url: mp4Url,
      webmUrl: webmUrl,
      gifUrl: gifUrl,
      width: width,
      height: height,
      format: ext,
      imageId: imageId,
    );
  }

  JoyreactorMediaDto? _parseImageElement({
    required dom.Element container,
    required dom.Element imgElem,
    required int index,
  }) {
    final rawSrc =
        (imgElem.attributes['src'] ?? imgElem.attributes['data-src'] ?? '')
            .trim();
    if (rawSrc.isEmpty) return null;

    final sampleUrl = normalizeUrl(rawSrc);

    // Check if wrapped in `<a class="prettyPhotoLink" href="...">` for full-res image
    String? fullHref;
    final isFullImageLink = container.localName == 'a' &&
        (container.classes.contains('prettyPhotoLink') ||
            (container.attributes['href'] ?? '').contains('/post/full/') ||
            (container.attributes['rel'] ?? '').startsWith('prettyPhoto'));
    final parentAnchor = isFullImageLink
        ? container
        : container.querySelector(
            'a.prettyPhotoLink, a[href*="/post/full/"], a[rel^="prettyPhoto"]',
          );
    if (parentAnchor != null) {
      final href = parentAnchor.attributes['href']?.trim() ?? '';
      if (href.isNotEmpty) {
        fullHref = normalizeUrl(href);
      }
    }

    // If no anchor wraps the image, derive full resolution URL using JoyReactor's `/pics/post/full/` convention
    final originalUrl = fullHref ?? deriveFullImageUrl(sampleUrl);

    final width = int.tryParse(imgElem.attributes['width'] ?? '');
    final height = int.tryParse(imgElem.attributes['height'] ?? '');
    final ext = _extractExtension(originalUrl) ?? _extractExtension(sampleUrl);
    final isGif = (ext?.toLowerCase() == 'gif');
    final imageId = _extractAttachmentId(originalUrl) ??
        _extractAttachmentId(sampleUrl);

    return JoyreactorMediaDto(
      index: index,
      thumbnailUrl: sampleUrl,
      sampleUrl: sampleUrl,
      originalUrl: originalUrl,
      type: isGif ? JoyreactorMediaType.gif : JoyreactorMediaType.image,
      gifUrl: isGif ? originalUrl : null,
      width: width,
      height: height,
      format: ext,
      imageId: imageId,
    );
  }

  bool _detectNsfw(dom.Element element, List<JoyreactorTagDto> tags) {
    if (element.classes.contains('nsfw') ||
        element.querySelector('.nsfw_post, .post_nsfw') != null) {
      return true;
    }
    for (final tag in tags) {
      if (_kNsfwTagMarkers.contains(tag.name.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  ({
    int? currentPageNumber,
    String? nextPageUrl,
    String? prevPageUrl,
  }) _parsePagination(dom.Document document) {
    final paginationRoot =
        document.querySelector('.pagination_expanded') ??
        document.querySelector('.pagination');
    if (paginationRoot == null) {
      return (
        currentPageNumber: null,
        nextPageUrl: null,
        prevPageUrl: null,
      );
    }

    int? currentPageNumber;
    final currentSpan = paginationRoot.querySelector('span.current, .current');
    if (currentSpan != null) {
      currentPageNumber = int.tryParse(currentSpan.text.trim());
    }

    String? nextPageUrl;
    String? prevPageUrl;

    // 1. Explicit `a.next` ("Дальше" / Next page of older posts)
    final nextAnchor = paginationRoot.querySelector('a.next');
    if (nextAnchor != null) {
      final href = nextAnchor.attributes['href']?.trim() ?? '';
      if (href.isNotEmpty) {
        nextPageUrl = normalizeUrl(href);
      }
    }

    // 2. Explicit `a.prev` ("Назад" / Newer posts)
    final prevAnchor = paginationRoot.querySelector('a.prev');
    if (prevAnchor != null) {
      final href = prevAnchor.attributes['href']?.trim() ?? '';
      if (href.isNotEmpty) {
        prevPageUrl = normalizeUrl(href);
      }
    }

    // 3. Fallback: some JoyReactor layouts omit `a.next` and place the older-page
    // link directly after `span.current`. Use the adjacent-sibling selector so this
    // also works when the pagination markup contains non-element nodes.
    if (nextPageUrl == null && currentSpan != null) {
      final nextSibling = paginationRoot.querySelector('span.current + a');
      final href = nextSibling?.attributes['href']?.trim() ?? '';
      if (href.isNotEmpty) {
        nextPageUrl = normalizeUrl(href);
      }
    }

    return (
      currentPageNumber: currentPageNumber,
      nextPageUrl: nextPageUrl,
      prevPageUrl: prevPageUrl,
    );
  }

  // ---------------------------------------------------------------------------
  // Static & Public URL / HTML Normalization Utilities
  // ---------------------------------------------------------------------------

  /// Normalizes relative, protocol-relative (`//img2.joyreactor.cc/...`), or `http://` URLs
  /// against [baseUrl], ensuring valid HTTPS URLs and decoded HTML entities.
  String normalizeUrl(String rawUrl) {
    final unescaped = unescapeHtml(rawUrl).trim();
    if (unescaped.isEmpty) return '';

    final baseUri = Uri.parse(baseUrl);
    final scheme = baseUri.scheme.isNotEmpty ? baseUri.scheme : 'https';

    if (unescaped.startsWith('//')) {
      return '$scheme:$unescaped';
    }
    if (unescaped.startsWith('http://') || unescaped.startsWith('https://')) {
      // Upgrade http:// reactor links to match base scheme if https
      if (scheme == 'https' &&
          unescaped.startsWith('http://') &&
          unescaped.contains('reactor.')) {
        return 'https://${unescaped.substring(7)}';
      }
      return unescaped;
    }
    if (unescaped.startsWith('/')) {
      return '${baseUri.scheme}://${baseUri.authorityOrHost}$unescaped';
    }
    return '${baseUri.scheme}://${baseUri.authorityOrHost}/$unescaped';
  }

  /// Converts a JoyReactor sample image URL (`/pics/post/foo-123.jpeg`)
  /// into its full-resolution counterpart (`/pics/post/full/foo-123.jpeg`).
  static String deriveFullImageUrl(String url) {
    if (url.contains('/pics/post/full/') ||
        url.contains('/pics/post/webm/') ||
        url.contains('/pics/post/mp4/')) {
      return url;
    }
    if (url.contains('/pics/post/')) {
      return url.replaceFirst('/pics/post/', '/pics/post/full/');
    }
    return url;
  }

  static String _deriveStaticPreviewFromMediaUrl(String mediaUrl) {
    // JoyReactor stores static JPEG previews for WebM/MP4/GIF posts at `/pics/post/poster/...` or `/pics/post/...jpeg`
    var preview = mediaUrl
        .replaceFirst('/pics/post/mp4/', '/pics/post/')
        .replaceFirst('/pics/post/webm/', '/pics/post/')
        .replaceFirst('/pics/post/full/', '/pics/post/');
    preview = preview.replaceFirst(
      RegExp(r'\.(mp4|webm|gif)(\?.*)?$', caseSensitive: false),
      '.jpeg',
    );
    return preview;
  }

  static String? _extractExtension(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) return null;
    final ext = path.substring(dotIndex + 1).toLowerCase();
    if (ext.length > 5 || ext.contains('/')) return null;
    return ext;
  }

  static int? _extractAttachmentId(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final match = RegExp(r'-(\d+)\.[a-zA-Z0-9]+$').firstMatch(path);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Encodes a tag for JoyReactor `/tag/<tag>` paths, converting spaces to `+`
  /// and percent-encoding Cyrillic and special characters cleanly.
  static String encodeTagForPath(String rawTag) {
    final normalized = rawTag.trim().replaceAll('_', ' ');
    return normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('+');
  }

  /// Unescapes standard HTML entities (`&amp;`, `&quot;`, `&#039;`, `&lt;`, `&gt;`, `&nbsp;`, numeric entities).
  static String unescapeHtml(String input) {
    if (!input.contains('&')) return input;
    final fragment = html_parser.parseFragment(input);
    return fragment.text ?? input;
  }
}

extension _UriAuthorityX on Uri {
  String get authorityOrHost => hasAuthority ? authority : host;
}
