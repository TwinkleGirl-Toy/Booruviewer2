import 'post_dto.dart';

class PawchivePageResultDto {
  const PawchivePageResultDto({
    required this.posts,
    required this.offset,
    this.count,
    this.trueCount,
  });

  final List<PawchivePostDto> posts;
  final int offset;
  final int? count;
  final int? trueCount;

  bool get hasMore {
    if (posts.isEmpty) return false;
    final total = trueCount ?? count;
    if (total != null) {
      return offset + posts.length < total;
    }
    return posts.length >= 25;
  }
}
