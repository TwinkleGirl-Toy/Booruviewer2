import 'media_dto.dart';
import 'tag_dto.dart';

class JoyreactorPostDto {
  const JoyreactorPostDto({
    required this.id,
    required this.postUrl,
    required this.tags,
    required this.media,
    this.authorName,
    this.authorId,
    this.authorAvatarUrl,
    this.createdAt,
    this.score,
    this.commentCount,
    this.title,
    this.description,
    this.isNsfw = false,
  });

  /// Canonical JoyReactor post ID (e.g., 5061838).
  final int id;

  /// Direct URL to the JoyReactor post (`https://joyreactor.cc/post/<id>`).
  final String postUrl;

  /// All tags extracted from the post's `.taglist` and/or JSON-LD headline.
  final List<JoyreactorTagDto> tags;

  /// Ordered list of media attachments belonging to this post.
  final List<JoyreactorMediaDto> media;

  /// Uploader username.
  final String? authorName;

  /// Uploader user ID if present in DOM attributes.
  final int? authorId;

  /// Uploader avatar URL if present.
  final String? authorAvatarUrl;

  /// Post creation timestamp in UTC.
  final DateTime? createdAt;

  /// Post score / rating (floating-point on JoyReactor, e.g. 42.5).
  final double? score;

  /// Number of comments on the post.
  final int? commentCount;

  /// Post title if present.
  final String? title;

  /// Post text description if present.
  final String? description;

  /// Whether the post is marked NSFW/unsafe or contains explicit tags (`эротика`, `nsfw`, `18+`, `порно`).
  final bool isNsfw;

  /// Convenience getter for the primary media attachment.
  JoyreactorMediaDto? get primaryMedia => media.isNotEmpty ? media.first : null;
}
