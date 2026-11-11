import 'file_dto.dart';

class PawchivePostDto {
  const PawchivePostDto({
    required this.id,
    required this.service,
    required this.userId,
    required this.title,
    required this.postUrl,
    required this.files,
    required this.tags,
    this.username,
    this.content,
    this.publishedAt,
    this.addedAt,
    this.editedAt,
    this.hasFull = true,
    this.previewState,
  });

  /// String post ID returned by Pawchive (e.g. `"27557901"`).
  final String id;

  /// Creator platform service (`patreon`, `fanbox`, `fantia`, `subscribestar`, `gumroad`, `boosty`, `discord`, `afdian`).
  final String service;

  /// Creator user ID on that service (e.g. `"568551"`).
  final String userId;

  /// Creator display username if available (e.g. `"Reinbach"`).
  final String? username;

  /// Post title.
  final String title;

  /// Canonical web URL to the post (`https://pawchive.pw/<service>/user/<userId>/post/<id>`).
  final String postUrl;

  /// Deduplicated, ordered media files (`file` + `attachments` + inline images).
  final List<PawchiveFileDto> files;

  /// Post tags (plus synthesized `service:<service>` and `creator:<username>` tags).
  final List<String> tags;

  /// Plain-text or HTML description body of the post.
  final String? content;

  /// Publication timestamp (timezone-aware; Fanbox defaults to `Asia/Tokyo` if naive).
  final DateTime? publishedAt;

  /// Timestamp when the post was added to Pawchive.
  final DateTime? addedAt;

  /// Timestamp when the post was last edited.
  final DateTime? editedAt;

  /// Whether full-resolution files have been archived (`has_full` in Pawchive API).
  final bool hasFull;

  /// Preview archive state (`preview_state`, e.g., `"scraped"`, `"preview_only"`).
  final String? previewState;

  /// Numeric post ID used by Boorusama's `SimplePost` (parsed int or deterministic positive hash).
  int get numericId {
    final parsed = int.tryParse(id);
    if (parsed != null && parsed > 0) return parsed;
    return id.codeUnits.fold<int>(0, (prev, elem) => (prev * 31 + elem) & 0x3fffffff);
  }
}
