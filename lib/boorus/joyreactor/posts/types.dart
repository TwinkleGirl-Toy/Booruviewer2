// Project imports:
import '../../../core/posts/post/types.dart';

class JoyreactorPost extends SimplePost {
  JoyreactorPost({
    required super.id,
    required this.parentPostId,
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
    super.commentCount,
    this.authorId,
    this.postUrl,
    this.isGif = false,
    this.title,
  });

  /// Canonical JoyReactor post ID.
  final int parentPostId;

  /// 0-based index of this attachment within a multi-image post.
  final int attachmentIndex;

  /// Total media attachments in the JoyReactor post.
  final int totalAttachments;

  final String? authorId;
  final String? postUrl;
  final bool isGif;
  final String? title;

  @override
  String get sitePostId => parentPostId > 0
      ? (totalAttachments > 1
            ? '${parentPostId}_${attachmentIndex + 1}'
            : parentPostId.toString())
      : super.sitePostId;
}
