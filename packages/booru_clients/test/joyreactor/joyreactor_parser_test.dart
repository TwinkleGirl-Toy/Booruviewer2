// Dart imports:
import 'dart:io';

// Package imports:
import 'package:booru_clients/joyreactor.dart';
import 'package:test/test.dart';

void main() {
  const parser = JoyreactorHtmlParser(baseUrl: 'https://joyreactor.cc');

  late String listingHtml;
  late String searchEdgeCasesHtml;

  setUpAll(() {
    listingHtml = File(
      'test/joyreactor/fixtures/listing_page.html',
    ).readAsStringSync();
    searchEdgeCasesHtml = File(
      'test/joyreactor/fixtures/search_and_edge_cases.html',
    ).readAsStringSync();
  });

  group('JoyreactorHtmlParser - listing page', () {
    test('extracts posts, IDs, URLs, authors, timestamps, scores, and tags', () {
      final result = parser.parsePage(
        listingHtml,
        currentUrl: 'https://joyreactor.cc/tag/Dark+Souls',
      );

      expect(result.posts, hasLength(3));
      expect(result.currentPageNumber, 124);
      expect(
        result.nextPageUrl,
        'https://joyreactor.cc/tag/Dark+Souls/123',
      );
      expect(
        result.prevPageUrl,
        'https://joyreactor.cc/tag/Dark+Souls/125',
      );

      final post1 = result.posts[0];
      expect(post1.id, 5061838);
      expect(post1.postUrl, 'https://joyreactor.cc/post/5061838');
      expect(post1.authorName, 'Artorias_RU');
      expect(post1.authorId, 12345);
      expect(
        post1.authorAvatarUrl,
        'https://img0.joyreactor.cc/pics/avatar/user/12345',
      );
      expect(
        post1.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1710512400 * 1000, isUtc: true),
      );
      expect(post1.score, closeTo(142.8, 0.001));
      expect(post1.commentCount, 14);
      expect(post1.title, 'Рыцарь Бездны');
      expect(post1.description, 'Первая часть комикса & иллюстрация');
      expect(post1.isNsfw, isFalse);

      // Verify decoded HTML entities & Cyrillic tags
      expect(
        post1.tags.map((t) => t.name).toList(),
        equals(['Dark Souls', 'Арториас', 'art & illustration']),
      );
      expect(
        post1.tags.map((t) => t.normalizedName).toList(),
        equals(['Dark_Souls', 'Арториас', 'art_&_illustration']),
      );
    });

    test('extracts multiple media attachments and normalizes full image URLs', () {
      final result = parser.parsePage(listingHtml);
      final post1 = result.posts[0];

      expect(post1.media, hasLength(2));

      final media0 = post1.media[0];
      expect(media0.index, 0);
      expect(media0.type, JoyreactorMediaType.image);
      expect(
        media0.thumbnailUrl,
        'https://img2.joyreactor.cc/pics/post/Dark-Souls-%D0%90%D1%80%D1%82%D0%BE%D1%80%D0%B8%D0%B0%D1%81-8401001.jpeg',
      );
      expect(
        media0.originalUrl,
        'https://img2.joyreactor.cc/pics/post/full/Dark-Souls-%D0%90%D1%80%D1%82%D0%BE%D1%80%D0%B8%D0%B0%D1%81-8401001.jpeg',
      );
      expect(media0.width, 800);
      expect(media0.height, 1200);
      expect(media0.format, 'jpeg');
      expect(media0.imageId, 8401001);

      // Second attachment had no prettyPhotoLink wrapper, so parser derives `/pics/post/full/`
      final media1 = post1.media[1];
      expect(media1.index, 1);
      expect(
        media1.thumbnailUrl,
        'https://img2.joyreactor.cc/pics/post/Dark-Souls-%D0%90%D1%80%D1%82%D0%BE%D1%80%D0%B8%D0%B0%D1%81-8401002.png',
      );
      expect(
        media1.originalUrl,
        'https://img2.joyreactor.cc/pics/post/full/Dark-Souls-%D0%90%D1%80%D1%82%D0%BE%D1%80%D0%B8%D0%B0%D1%81-8401002.png',
      );
      expect(media1.width, 1024);
      expect(media1.height, 768);
      expect(media1.format, 'png');
      expect(media1.imageId, 8401002);
    });

    test('extracts video and animated GIF sources with poster thumbnail', () {
      final result = parser.parsePage(listingHtml);
      final post2 = result.posts[1];

      expect(post2.id, 5061839);
      expect(post2.media, hasLength(1));

      final videoMedia = post2.media.first;
      expect(videoMedia.type, JoyreactorMediaType.video);
      expect(
        videoMedia.thumbnailUrl,
        'https://img1.joyreactor.cc/pics/post/poster/anime-%D0%B3%D0%B8%D1%84%D0%BA%D0%B8-8402001.jpeg',
      );
      expect(
        videoMedia.mp4Url,
        'https://img1.joyreactor.cc/pics/post/mp4/anime-%D0%B3%D0%B8%D1%84%D0%BA%D0%B8-8402001.mp4',
      );
      expect(
        videoMedia.webmUrl,
        'https://img1.joyreactor.cc/pics/post/webm/anime-%D0%B3%D0%B8%D1%84%D0%BA%D0%B8-8402001.webm',
      );
      expect(
        videoMedia.gifUrl,
        'https://img1.joyreactor.cc/pics/post/full/anime-%D0%B3%D0%B8%D1%84%D0%BA%D0%B8-8402001.gif',
      );
      // Prefers MP4 stream for playback compatibility
      expect(videoMedia.videoUrl, videoMedia.mp4Url);
      expect(videoMedia.width, 600);
      expect(videoMedia.height, 338);
    });

    test('detects NSFW posts and handles unrated ("--") score gracefully', () {
      final result = parser.parsePage(listingHtml);
      final post3 = result.posts[2];

      expect(post3.id, 5061840);
      expect(post3.isNsfw, isTrue);
      expect(post3.score, isNull);
    });
  });

  group('JoyreactorHtmlParser - search, edge cases, and URL encoding', () {
    test('deduplicates repeated posts, preserves iframe embeds, and falls back to JSON-LD tags', () {
      final result = parser.parsePage(searchEdgeCasesHtml);

      // Post 6001001 appears twice in HTML and Post 6001002 is text-only
      expect(result.posts, hasLength(1));

      final post = result.posts.first;
      expect(post.id, 6001001);
      expect(post.score, closeTo(-4.5, 0.001));
      expect(
        post.tags.map((t) => t.name).toList(),
        equals(['Warhammer 40000', 'Комиксы']),
      );
      expect(post.media, hasLength(1));
      expect(post.media.first.type, JoyreactorMediaType.embed);
      expect(
        post.media.first.originalUrl,
        'https://www.youtube.com/embed/dQw4w9WgXcQ',
      );

      // Pagination sibling fallback when `a.next` is absent
      expect(result.currentPageNumber, 10);
      expect(
        result.nextPageUrl,
        'https://joyreactor.cc/search?q=Warhammer+40000&page=9',
      );
    });

    test('encodes Cyrillic and multi-word tags properly for JoyReactor URLs', () {
      expect(
        JoyreactorHtmlParser.encodeTagForPath('Dark Souls 3'),
        'Dark+Souls+3',
      );
      expect(
        JoyreactorHtmlParser.encodeTagForPath('Арториас_из_Бездны'),
        '%D0%90%D1%80%D1%82%D0%BE%D1%80%D0%B8%D0%B0%D1%81+%D0%B8%D0%B7+%D0%91%D0%B5%D0%B7%D0%B4%D0%BD%D1%8B',
      );
    });

    test('parses tag suggestions from HTML and JSON formats', () {
      final fromHtml = parser.parseTagSuggestions(searchEdgeCasesHtml);
      expect(
        fromHtml.map((t) => t.name).toList(),
        containsAll(['Warhammer 40000', 'Комиксы']),
      );

      final fromJson = parser.parseTagSuggestions(
        '[{"name": "Арториас", "count": 42}, {"name": "Dark Souls", "count": 500}]',
      );
      expect(fromJson, hasLength(2));
      expect(fromJson.first.name, 'Арториас');
      expect(fromJson.first.count, 42);
    });
  });
}
