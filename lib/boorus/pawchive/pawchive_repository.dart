// Package imports:
import 'package:booru_clients/pawchive.dart';
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

const kPawchiveCustomDownloadFileNameFormat =
    '{id}_{width}x{height}.{extension}';

class PawchiveRepository extends BooruRepositoryDefault {
  const PawchiveRepository({required this.ref});

  @override
  final Ref ref;

  @override
  PostRepository<Post> post(BooruConfigSearch config) {
    return ref.read(pawchivePostRepoProvider(config));
  }

  @override
  AutocompleteRepository autocomplete(BooruConfigAuth config) {
    return ref.read(pawchiveAutocompleteRepoProvider(config));
  }

  @override
  BooruSiteValidator? siteValidator(BooruConfigAuth config) {
    final dio = ref.watch(pawchiveDioProvider(config));

    return () => PawchiveClient(
      dio: dio,
      baseUrl: config.url,
    ).getPosts().then((value) => true);
  }

  @override
  PostLinkGenerator<Post> postLinkGenerator(BooruConfigAuth config) {
    return PawchivePostLinkGenerator(baseUrl: config.url);
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
      defaultFileNameFormat: kPawchiveCustomDownloadFileNameFormat,
      defaultBulkDownloadFileNameFormat: kPawchiveCustomDownloadFileNameFormat,
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
    return const PawchiveDownloadFileUrlExtractor();
  }

  @override
  Dio dio(BooruConfigAuth config) {
    return ref.watch(pawchiveDioProvider(config));
  }
}

class PawchivePostLinkGenerator<T extends Post>
    implements PostLinkGenerator<T> {
  const PawchivePostLinkGenerator({
    required this.baseUrl,
  });

  final String baseUrl;

  @override
  String getLink(T post) {
    final url = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    if (post is PawchivePost) {
      if (post.postUrl case final postUrl? when postUrl.isNotEmpty) {
        return postUrl;
      }
      if (post.service.isNotEmpty &&
          post.creatorId.isNotEmpty &&
          post.rawPostId.isNotEmpty) {
        return '$url/${post.service}/user/${post.creatorId}/post/${post.rawPostId}';
      }
    }

    return '$url/posts';
  }
}

class PawchiveDownloadFileUrlExtractor implements DownloadFileUrlExtractor {
  const PawchiveDownloadFileUrlExtractor();

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
