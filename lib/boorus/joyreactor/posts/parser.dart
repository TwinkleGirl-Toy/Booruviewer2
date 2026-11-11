// Package imports:
import 'package:booru_clients/joyreactor.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/posts/sources/types.dart';
import 'types.dart';

/// Expands a [JoyreactorPostDto] into one or more [JoyreactorPost] items so that
/// multi-image JoyReactor posts preserve every image/video attachment in Boorusama's
/// grid, viewer, and bulk download manager without discarding attachments.
List<JoyreactorPost> parseJoyreactorPostDto(
  JoyreactorPostDto dto, {
  PostMetadata? metadata,
}) {
  if (dto.media.isEmpty) return const [];

  final normalizedTags = dto.tags
      .map((t) => t.normalizedName)
      .where((t) => t.isNotEmpty)
      .toSet();
  final rawTags = dto.tags.map((t) => t.name).where((t) => t.isNotEmpty).toList();
  final rating = dto.isNsfw ? Rating.explicit : Rating.general;
  final hasComments = (dto.commentCount ?? 0) > 0;
  final totalAttachments = dto.media.length;
  final hasMultiple = totalAttachments > 1;
  final scoreInt = dto.score?.round() ?? 0;

  final results = <JoyreactorPost>[];

  for (var i = 0; i < totalAttachments; i++) {
    final media = dto.media[i];
    // First attachment uses the canonical post ID; subsequent attachments receive
    // a deterministic synthetic ID (`dto.id * 100 + i`) so grid selection, bookmarks,
    // and downloads treat each attachment uniquely while preserving `parentPostId`.
    final postId = i == 0 ? dto.id : (dto.id * 100 + i);
    final isVideo = media.isVideo;
    final format = media.format ?? (isVideo ? 'mp4' : 'jpeg');

    results.add(
      JoyreactorPost(
        id: postId,
        parentPostId: dto.id,
        attachmentIndex: i,
        attachmentCount: totalAttachments,
        thumbnailImageUrl: media.thumbnailUrl,
        sampleImageUrl: media.sampleUrl,
        originalImageUrl: media.originalUrl,
        tags: normalizedTags,
        rawTags: rawTags,
        rating: rating,
        hasComment: hasComments,
        isTranslated: false,
        hasParentOrChildren: hasMultiple,
        parentId: i > 0 ? dto.id : null,
        source: PostSource.from(dto.postUrl),
        score: scoreInt,
        duration: 0,
        fileSize: 0,
        format: format,
        hasSound: isVideo ? null : false,
        height: (media.height ?? 0).toDouble(),
        width: (media.width ?? 0).toDouble(),
        md5: '${dto.id}_${media.imageId ?? i}',
        videoThumbnailUrl: media.thumbnailUrl,
        videoUrl: media.videoUrl ?? '',
        uploaderId: dto.authorId,
        uploaderName: dto.authorName,
        createdAt: dto.createdAt,
        metadata: metadata,
        postUrl: dto.postUrl,
        title: dto.title,
        description: dto.description,
        commentCount: dto.commentCount,
        gifUrl: media.gifUrl,
      ),
    );
  }

  return results;
}
