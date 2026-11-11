// Package imports:
import 'package:booru_clients/joyreactor.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/posts/sources/types.dart';
import '../../../foundation/path.dart' as path;
import 'types.dart';

List<JoyreactorPost> postDtoToPosts(
  JoyreactorPostDto dto,
  PostMetadata? metadata,
) {
  final postId = dto.id;
  if (postId == null) return const [];

  final attachments = dto.attachments ?? const <JoyreactorMediaAttachmentDto>[];
  if (attachments.isEmpty) return const [];

  final tags = <String>{
    for (final t in dto.tags ?? const <String>[])
      if (t.trim().isNotEmpty) t.trim().replaceAll(' ', '_'),
  };

  final score = (dto.score ?? 0).round();
  final commentCount = dto.commentCount ?? 0;
  final hasComments = commentCount > 0;
  final postUrl = dto.postUrl;
  final source = PostSource.from(postUrl);

  final results = <JoyreactorPost>[];
  final total = attachments.length;

  for (var i = 0; i < total; i++) {
    final attachment = attachments[i];
    final thumbUrl = attachment.thumbnailUrl ?? '';
    final fullUrl = attachment.fullImageUrl ?? thumbUrl;
    final videoUrl =
        attachment.videoUrl ?? (attachment.isVideo ? fullUrl : '');
    final isVideo = attachment.isVideo && videoUrl.isNotEmpty;

    final format = _extractFormat(
      isVideo ? videoUrl : fullUrl,
      fallbackFormat: attachment.format,
    );

    final syntheticId = total == 1 ? postId : (postId * 100 + i + 1);

    results.add(
      JoyreactorPost(
        id: syntheticId,
        parentPostId: postId,
        attachmentIndex: i,
        totalAttachments: total,
        thumbnailImageUrl: thumbUrl,
        sampleImageUrl: isVideo ? thumbUrl : thumbUrl,
        originalImageUrl: isVideo ? videoUrl : fullUrl,
        tags: tags,
        rating: Rating.general,
        hasComment: hasComments,
        commentCount: commentCount,
        isTranslated: false,
        hasParentOrChildren: total > 1,
        source: source,
        score: score,
        duration: kNoduration,
        fileSize: 0,
        format: format,
        hasSound: isVideo ? null : false,
        height: (attachment.height ?? 0).toDouble(),
        width: (attachment.width ?? 0).toDouble(),
        md5: '',
        videoThumbnailUrl: isVideo ? thumbUrl : '',
        videoUrl: isVideo ? videoUrl : '',
        uploaderId: null,
        uploaderName: dto.authorName,
        createdAt: dto.createdAt,
        metadata: metadata,
        authorId: dto.authorId,
        postUrl: postUrl,
        isGif: attachment.isGif,
        title: dto.title,
      ),
    );
  }

  return results;
}

String _extractFormat(String url, {String? fallbackFormat}) {
  if (url.isNotEmpty) {
    final cleanUrl = url.split('?').first.split('#').first;
    final ext = path.extension(cleanUrl).toLowerCase();
    if (ext.isNotEmpty) {
      return ext;
    }
  }
  if (fallbackFormat != null && fallbackFormat.isNotEmpty) {
    return fallbackFormat.startsWith('.')
        ? fallbackFormat.toLowerCase()
        : '.${fallbackFormat.toLowerCase()}';
  }
  return '.jpg';
}
