enum PawchiveMediaType {
  image,
  gif,
  video,
  archive,
}

class PawchiveFileDto {
  const PawchiveFileDto({
    required this.index,
    required this.name,
    required this.path,
    required this.thumbnailUrl,
    required this.sampleUrl,
    required this.originalUrl,
    required this.type,
    required this.extension,
    this.server,
    this.tempUrl,
    this.isPreviewOnly = false,
    this.isDeferred = false,
    this.hash,
  });

  /// 0-based index of this media file within the parent Pawchive post.
  final int index;

  /// Original creator-supplied filename (e.g. `Fuck_Yeah_Zelda_2_copy.jpg`).
  final String name;

  /// Relative storage path (e.g. `/136/e8/36e8bad834ed5b7bcadfbde9d4448535494a8f92e9a62ff1367f324ef02e5d75.jpg`).
  final String path;

  /// Thumbnail URL on `https://img.pawchive.pw/thumbnail/data/...`.
  final String thumbnailUrl;

  /// Sample/preview image URL.
  final String sampleUrl;

  /// Full-resolution image or video URL (or `thumbnailUrl` fallback when `isPreviewOnly` is true).
  final String originalUrl;

  /// Media classification (`image`, `gif`, `video`, or `archive`).
  final PawchiveMediaType type;

  /// Lowercase file extension without leading dot (`jpg`, `png`, `gif`, `mp4`, `webm`, etc.).
  final String extension;

  /// Specific CDN server returned by the API (e.g. `https://n2.pawchive.pw` or `https://file.pawchive.pw`).
  final String? server;

  /// Signed temporary download URL (e.g. `https://t1.pawchive.pw/f/...?e=...&s=...`) when present.
  final String? tempUrl;

  /// True when the full-resolution file is not archived on Pawchive (`preview_only` / `has_full: false`)
  /// and only the `img.pawchive.pw` thumbnail is available.
  final bool isPreviewOnly;

  /// True when the file is marked `deferred: true` on Pawchive.
  final bool isDeferred;

  /// SHA-256 hash extracted from the storage path if present.
  final String? hash;

  bool get isVideo => type == PawchiveMediaType.video;
  bool get isGif => type == PawchiveMediaType.gif;
}
