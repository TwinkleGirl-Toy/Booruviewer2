// Dart imports:
import 'dart:io';

// Package imports:
import 'package:booru_clients/pawchive.dart';
import 'package:test/test.dart';

void main() {
  const parser = PawchiveParser(
    baseUrl: 'https://pawchive.pw',
    fileHostUrl: 'https://file.pawchive.pw',
    thumbnailHostUrl: 'https://img.pawchive.pw',
  );

  late String postsJson;

  setUpAll(() {
    postsJson = File(
      'test/pawchive/fixtures/posts_response.json',
    ).readAsStringSync();
  });

  group('PawchiveParser - posts, deduplication, preview_only, and temp_url', () {
    test('parses post metadata, deduplicates file vs attachments, and skips archive zip files', () {
      final page = parser.parsePostsPage(postsJson, offset: 0);

      expect(page.posts, hasLength(3));
      expect(page.count, 3);
      expect(page.trueCount, 120);
      expect(page.hasMore, isTrue);

      final post1 = page.posts[0];
      expect(post1.id, '27557901');
      expect(post1.numericId, 27557901);
      expect(post1.service, 'patreon');
      expect(post1.userId, '568551');
      expect(post1.username, 'Reinbach');
      expect(post1.title, 'Zelda Sketch');
      expect(
        post1.postUrl,
        'https://pawchive.pw/patreon/user/568551/post/27557901',
      );
      expect(
        post1.content,
        'Whipped this one up this morning to celebrate the announcement of Breath of the Wild 2.',
      );

      // Verify synthesized service/artist/user tags + post tags
      expect(
        post1.tags,
        containsAll([
          'patreon',
          'artist:Reinbach',
          'patreon:user:568551',
          'zelda',
          'sketch',
          'breath_of_the_wild',
        ]),
      );

      // `file` and `attachments[0]` had identical SHA-256 hash, and `attachments[2]` was a `.zip`
      // so `post1.files` has exactly 2 visual media attachments.
      expect(post1.files, hasLength(2));

      final f0 = post1.files[0];
      expect(f0.name, 'Fuck_Yeah_Zelda_2_copy.jpg');
      expect(
        f0.thumbnailUrl,
        'https://img.pawchive.pw/thumbnail/data/136/e8/36e8bad834ed5b7bcadfbde9d4448535494a8f92e9a62ff1367f324ef02e5d75.jpg',
      );
      expect(
        f0.originalUrl,
        'https://n2.pawchive.pw/data/136/e8/36e8bad834ed5b7bcadfbde9d4448535494a8f92e9a62ff1367f324ef02e5d75.jpg',
      );
      expect(f0.isPreviewOnly, isFalse);

      final f1 = post1.files[1];
      expect(f1.name, 'Zelda_Alt_Variant.png');
      expect(
        f1.originalUrl,
        'https://file.pawchive.pw/data/13/10/13106763094e0401150fb97c74a8bb729c8bed677f562b7e82db148a92440047.png',
      );
    });

    test('handles preview_only fallback, signed temp_url (/f/), and Fanbox Asia/Tokyo timestamps', () {
      final page = parser.parsePostsPage(postsJson, offset: 0);
      final post2 = page.posts[1];

      expect(post2.id, '10196562');
      expect(post2.service, 'fanbox');
      expect(post2.hasFull, isFalse);

      // 2 valid files (`empty_deferred.png` without path/url/temp_url is ignored)
      expect(post2.files, hasLength(2));

      // First file is preview_only without temp_url -> originalUrl falls back to img.pawchive.pw thumbnail
      final previewFile = post2.files[0];
      expect(previewFile.isPreviewOnly, isTrue);
      expect(
        previewFile.originalUrl,
        'https://img.pawchive.pw/thumbnail/data/ab/cd/abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789.png',
      );

      // Second file has signed temp_url on t1.pawchive.pw/f/ -> preserves full signed URL
      final signedFile = post2.files[1];
      expect(signedFile.isPreviewOnly, isFalse);
      expect(
        signedFile.originalUrl,
        'https://t1.pawchive.pw/f/ef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd.png?e=1790000000&s=sig123',
      );

      // Fanbox naive timestamp "2026-08-15T12:00:00" is interpreted as Asia/Tokyo (+09:00) -> 03:00:00 UTC
      expect(
        post2.publishedAt,
        DateTime.utc(2026, 8, 15, 3, 0, 0),
      );
    });

    test('parses video attachments accurately', () {
      final page = parser.parsePostsPage(postsJson, offset: 0);
      final post3 = page.posts[2];

      expect(post3.files, hasLength(1));
      final video = post3.files.first;
      expect(video.isVideo, isTrue);
      expect(video.extension, 'mp4');
      expect(
        video.originalUrl,
        'https://file.pawchive.pw/data/d4/53/d4533ccd43fb0b6c037ec4a0ead757b8b5a93657a097856dbb8dfc56c8b7b797.mp4',
      );
    });
  });
}
