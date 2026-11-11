enum JoyreactorMediaType {
  image,
  gif,
  video,
  embed,
}

class JoyreactorMediaDto {
  const JoyreactorMediaDto({
    required this.index,
    required this.thumbnailUrl,
    required this.sampleUrl,
    required this.originalUrl,
    required this.type,
    this.videoUrl,
    this.mp4Url,
    this.webmUrl,
    this.gifUrl,
    this.width,
    this.height,
    this.format,
    this.imageId,
  });

  /// 0-based index of this attachment within the parent JoyReactor post.
  final int index;

  /// Preview/thumbnail image URL for the grid.
  final String thumbnailUrl;

  /// Medium/sample resolution image URL.
  final String sampleUrl;

  /// Full-resolution image or downloadable media URL.
  final String originalUrl;

  /// Media classification (static image, animated GIF, video, or external embed).
  final JoyreactorMediaType type;

  /// Direct playable video stream URL (MP4 preferred over WebM for mobile compatibility).
  final String? videoUrl;

  /// Direct MP4 stream URL if available.
  final String? mp4Url;

  /// Direct WebM stream URL if available.
  final String? webmUrl;

  /// Original animated GIF URL if available.
  final String? gifUrl;

  /// Media width in pixels if specified in the HTML.
  final int? width;

  /// Media height in pixels if specified in the HTML.
  final int? height;

  /// File extension / format (e.g., 'jpeg', 'png', 'gif', 'mp4', 'webm').
  final String? format;

  /// Numeric image attachment ID extracted from the filename if present.
  final int? imageId;

  bool get isVideo => type == JoyreactorMediaType.video;
  bool get isGif => type == JoyreactorMediaType.gif;
}
