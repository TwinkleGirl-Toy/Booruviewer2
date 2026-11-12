// Package imports:
import 'package:booru_clients/pawchive.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/posts/sources/types.dart';
import '../../../foundation/path.dart' as path;
import 'types.dart';

List<PawchivePost> postDtoToPosts(
  PawchivePostDto dto,
  PostMetadata? metadata,
) {
  final baseId = dto.numericId;
  final attachments = dto.files;
  if (attachments.isEmpty) return const [];

  final tags = <String>{
    for (final t in dto.tags)
      if (t.trim().isNotEmpty) t.trim().replaceAll(' ', '_'),
  };

  final postUrl = dto.postUrl;
  final source = PostSource.from(postUrl);
  final total = attachments.length;
  final results = <PawchivePost>[];

  for (var i = 0; i < total; i++) {
    final attachment = attachments[i];
    final thumbUrl = attachment.thumbnailUrl;
    final fullUrl = attachment.originalUrl;
    final videoUrl = attachment.tempUrl ?? (attachment.isVideo ? fullUrl : '');
    final isVideo = attachment.isVideo && videoUrl.isNotEmpty;

    final format = _extractFormat(
      isVideo ? videoUrl : fullUrl,
      fallbackFormat: attachment.extension,
    );

    final syntheticId = total == 1 ? baseId : (baseId * 100 + i + 1);

    results.add(
      PawchivePost(
        id: syntheticId,
        rawPostId: dto.id,
        service: dto.service,
        creatorId: dto.userId,
        attachmentIndex: i,
        totalAttachments: total,
        thumbnailImageUrl: thumbUrl,
        sampleImageUrl: isVideo ? thumbUrl : fullUrl,
        originalImageUrl: isVideo ? videoUrl : fullUrl,
        tags: tags,
        rating: Rating.general,
        hasComment: false,
        isTranslated: false,
        hasParentOrChildren: total > 1,
        source: source,
        score: total,
        duration: kNoduration,
        fileSize: 0,
        format: format,
        hasSound: isVideo ? null : false,
        height: (attachment.height ?? 0).toDouble(),
        width: (attachment.width ?? 0).toDouble(),
        md5: '',
        videoThumbnailUrl: isVideo ? thumbUrl : '',
        videoUrl: isVideo ? videoUrl : '',
        uploaderId: int.tryParse(dto.userId),
        uploaderName: dto.username,
        createdAt: dto.publishedAt,
        metadata: metadata,
        postUrl: postUrl,
        title: dto.title,
        content: dto.content,
        originalFilename: attachment.name,
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
