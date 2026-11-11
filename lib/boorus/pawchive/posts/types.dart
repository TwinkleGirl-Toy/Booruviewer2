// Project imports:
import '../../../core/posts/post/types.dart';

class PawchivePost extends SimplePost {
  PawchivePost({
    required super.id,
    required this.rawPostId,
    required this.service,
    required this.creatorId,
    required this.attachmentIndex,
    required this.totalAttachments,
    required super.thumbnailImageUrl,
    required super.sampleImageUrl,
    required super.originalImageUrl,
    required super.tags,
    required super.rating,
    required super.hasComment,
    required super.isTranslated,
    required super.hasParentOrChildren,
    required super.source,
    required super.score,
    required super.duration,
    required super.fileSize,
    required super.format,
    required super.hasSound,
    required super.height,
    required super.md5,
    required super.videoThumbnailUrl,
    required super.videoUrl,
    required super.width,
    required super.uploaderId,
    required super.uploaderName,
    required super.createdAt,
    required super.metadata,
    this.postUrl,
    this.title,
    this.content,
    this.originalFilename,
  });

  /// Canonical Pawchive post ID string (e.g., "146086399").
  final String rawPostId;

  /// Creator platform service (e.g., "patreon", "fanbox", "gumroad").
  final String service;

  /// Creator ID on that service.
  final String creatorId;

  /// 0-based index of this attachment within a multi-media post.
  final int attachmentIndex;

  /// Total media attachments in the post.
  final int totalAttachments;

  final String? postUrl;
  final String? title;
  final String? content;
  final String? originalFilename;

  @override
  String get sitePostId => rawPostId.isNotEmpty
      ? (totalAttachments > 1
            ? '${rawPostId}_${attachmentIndex + 1}'
            : rawPostId)
      : super.sitePostId;
}
