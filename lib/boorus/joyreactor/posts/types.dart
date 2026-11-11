// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../core/posts/post/types.dart';

class JoyreactorPost extends SimplePost with EquatableMixin {
  JoyreactorPost({
    required super.id,
    required this.parentPostId,
    required this.attachmentIndex,
    required this.attachmentCount,
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
    required super.createdAt,
    required super.uploaderName,
    required super.metadata,
    this.postUrl,
    this.title,
    this.description,
    this.commentCount,
    this.gifUrl,
    this.rawTags = const [],
  });

  /// Canonical JoyReactor post ID on the website (`https://joyreactor.cc/post/<parentPostId>`).
  final int parentPostId;

  /// 0-based index of this media item within a multi-image JoyReactor post.
  final int attachmentIndex;

  /// Total number of media attachments in the parent JoyReactor post.
  final int attachmentCount;

  /// Direct URL to the JoyReactor post (`https://joyreactor.cc/post/<parentPostId>`).
  final String? postUrl;

  /// Optional post headline/title.
  final String? title;

  /// Optional post text caption/description.
  final String? description;

  /// Number of comments on the JoyReactor post.
  final int? commentCount;

  /// Original animated GIF URL when JoyReactor serves a WebM/MP4 conversion.
  final String? gifUrl;

  /// Original human-readable tags with spaces preserved (for display and external links).
  final List<String> rawTags;

  String getLink(String baseUrl) {
    if (postUrl != null && postUrl!.isNotEmpty) {
      return postUrl!;
    }
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$cleanBase/post/$parentPostId';
  }
}
