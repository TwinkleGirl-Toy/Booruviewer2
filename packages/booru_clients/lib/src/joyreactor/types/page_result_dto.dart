import 'post_dto.dart';

class JoyreactorPageResultDto {
  const JoyreactorPageResultDto({
    required this.posts,
    required this.currentUrl,
    this.currentPageNumber,
    this.nextPageUrl,
    this.prevPageUrl,
  });

  /// Parsed posts from the current HTML document.
  final List<JoyreactorPostDto> posts;

  /// Effective URL of the page that was parsed.
  final String currentUrl;

  /// Reverse-numbered page index shown in `.pagination .current` on JoyReactor, if present.
  final int? currentPageNumber;

  /// Resolved URL of the next page in the user's chronological scroll direction
  /// (older posts, which JoyReactor labels with `a.next` or the link immediately
  /// following `span.current` in `.pagination_expanded`).
  final String? nextPageUrl;

  /// Resolved URL of the newer page if present (`a.prev`).
  final String? prevPageUrl;

  bool get hasNextPage => nextPageUrl != null && nextPageUrl!.isNotEmpty;
}
