// Project imports:
import '../../../core/downloads/filename/types.dart';
import '../../../core/downloads/urls/types.dart';
import '../../../core/posts/post/types.dart';
import '../posts/types.dart';

class JoyreactorDownloadFileUrlExtractor implements DownloadFileUrlExtractor {
  const JoyreactorDownloadFileUrlExtractor();

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) async {
    if (post is JoyreactorPost) {
      if (quality == 'sample' && post.sampleImageUrl.isNotEmpty) {
        return DownloadUrlData.urlOnly(post.sampleImageUrl);
      }
      if (post.isVideo && post.videoUrl.isNotEmpty) {
        return DownloadUrlData.urlOnly(post.videoUrl);
      }
      if (post.originalImageUrl.isNotEmpty) {
        return DownloadUrlData.urlOnly(post.originalImageUrl);
      }
    }

    final fallback = post.originalImageUrl.isNotEmpty
        ? post.originalImageUrl
        : post.sampleImageUrl;
    return fallback.isNotEmpty ? DownloadUrlData.urlOnly(fallback) : null;
  }
}

DownloadFilenameGenerator<Post> createJoyreactorDownloadFilenameGenerator() {
  return DownloadFileNameBuilder<Post>(
    defaultFileNameFormat: '{id}.{extension}',
    defaultBulkDownloadFileNameFormat: '{search}/{id}.{extension}',
    sampleData: const [
      {'id': '5061838', 'extension': 'jpeg', 'search': 'Dark_Souls'},
    ],
    hasMd5: false,
    hasRating: false,
    tokenHandlers: [
      TokenHandler<Post>(
        'id',
        (post, options) => post is JoyreactorPost
            ? post.parentPostId.toString()
            : post.id.toString(),
      ),
    ],
  );
}
