// Package imports:
import 'package:booru_clients/joyreactor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/boorus/defaults/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/create.dart';
import '../../core/downloads/filename/types.dart';
import '../../core/downloads/urls/types.dart';
import '../../core/posts/post/types.dart';
import '../../core/tags/autocompletes/types.dart';
import 'client_provider.dart';
import 'posts/providers.dart';
import 'posts/types.dart';
import 'tags/providers.dart';

const kJoyreactorCustomDownloadFileNameFormat =
    '{id}_{width}x{height}.{extension}';

class JoyreactorRepository extends BooruRepositoryDefault {
  const JoyreactorRepository({required this.ref});

  @override
  final Ref ref;

  @override
  PostRepository<Post> post(BooruConfigSearch config) {
    return ref.read(joyreactorPostRepoProvider(config));
  }

  @override
  AutocompleteRepository autocomplete(BooruConfigAuth config) {
    return ref.read(joyreactorAutocompleteRepoProvider(config));
  }

  @override
  BooruSiteValidator? siteValidator(BooruConfigAuth config) {
    final dio = ref.watch(joyreactorDioProvider(config));

    return () => JoyreactorClient(
      dio: dio,
      baseUrl: config.url,
    ).getPosts().then((value) => true);
  }

  @override
  PostLinkGenerator<Post> postLinkGenerator(BooruConfigAuth config) {
    return JoyreactorPostLinkGenerator(baseUrl: config.url);
  }

  @override
  Map<String, String> extraHttpHeaders(BooruConfigAuth config) {
    final referer = config.url.endsWith('/') ? config.url : '${config.url}/';
    return {
      'Referer': referer,
    };
  }

  @override
  DownloadFilenameGenerator<Post> downloadFilenameBuilder(
    BooruConfigAuth config,
  ) {
    return DownloadFileNameBuilder<Post>(
      defaultFileNameFormat: kJoyreactorCustomDownloadFileNameFormat,
      defaultBulkDownloadFileNameFormat:
          kJoyreactorCustomDownloadFileNameFormat,
      sampleData: kDanbooruPostSamples,
      hasMd5: false,
      hasRating: false,
      tokenHandlers: [
        WidthTokenHandler(),
        HeightTokenHandler(),
        AspectRatioTokenHandler(),
      ],
    );
  }

  @override
  DownloadFileUrlExtractor downloadFileUrlExtractor(BooruConfigAuth config) {
    return const JoyreactorDownloadFileUrlExtractor();
  }

  @override
  Dio dio(BooruConfigAuth config) {
    return ref.watch(joyreactorDioProvider(config));
  }
}

class JoyreactorPostLinkGenerator<T extends Post>
    implements PostLinkGenerator<T> {
  const JoyreactorPostLinkGenerator({
    required this.baseUrl,
  });

  final String baseUrl;

  @override
  String getLink(T post) {
    final url = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    if (post is JoyreactorPost) {
      if (post.postUrl case final postUrl? when postUrl.isNotEmpty) {
        return postUrl;
      }
      return '$url/post/${post.parentPostId}';
    }

    return '$url/post/${post.id}';
  }
}

class JoyreactorDownloadFileUrlExtractor implements DownloadFileUrlExtractor {
  const JoyreactorDownloadFileUrlExtractor();

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) async {
    if (post.isVideo && post.videoUrl.isNotEmpty) {
      return DownloadUrlData.urlOnly(post.videoUrl);
    }

    if (post.originalImageUrl.isNotEmpty) {
      return DownloadUrlData.urlOnly(post.originalImageUrl);
    }

    if (post.sampleImageUrl.isNotEmpty) {
      return DownloadUrlData.urlOnly(post.sampleImageUrl);
    }

    if (post.thumbnailImageUrl.isNotEmpty) {
      return DownloadUrlData.urlOnly(post.thumbnailImageUrl);
    }

    return null;
  }
}
