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
  final baseId = dto.id;
  if (baseId == null) return const [];

  final attachments = dto.attachments ?? const <PawchiveMediaAttachmentDto>[];
  if (attachments.isEmpty) return const [];

  final tags = <String>{
    for (final t in dto.tags ?? const <String>[])
      if (t.trim().isNotEmpty) t.trim().replaceAll(' ', '_'),
  };

  final postUrl = dto.postUrl;
  final source = PostSource.from(postUrl);
  final total = attachments.length;
  final results = <PawchivePost>[];

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

    final syntheticId = total == 1 ? baseId : (baseId * 100 + i + 1);

    results.add(
      PawchivePost(
        id: syntheticId,
        rawPostId: dto.rawId ?? baseId.toString(),
        service: dto.service ?? 'patreon',
        creatorId: dto.creatorId ?? '',
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
        score: dto.attachmentCount ?? total,
        duration: kNoduration,
        fileSize: 0,
        format: format,
        hasSound: isVideo ? null : false,
        height: (attachment.height ?? 0).toDouble(),
        width: (attachment.width ?? 0).toDouble(),
        md5: '',
        videoThumbnailUrl: isVideo ? thumbUrl : '',
        videoUrl: isVideo ? videoUrl : '',
        uploaderId: int.tryParse(dto.creatorId ?? ''),
        uploaderName: dto.creatorName ?? dto.creatorId,
        createdAt: dto.createdAt,
        metadata: metadata,
        postUrl: postUrl,
        title: dto.title,
        content: dto.content,
        originalFilename: attachment.filename,
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
