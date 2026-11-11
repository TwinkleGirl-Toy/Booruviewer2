class PawchiveCreatorDto {
  const PawchiveCreatorDto({
    required this.id,
    required this.name,
    required this.service,
    this.publicId,
    this.everImported = true,
    this.favorited,
    this.indexed,
    this.updated,
  });

  final String id;
  final String name;
  final String service;
  final String? publicId;
  final bool everImported;
  final int? favorited;
  final DateTime? indexed;
  final DateTime? updated;

  /// Canonical search metatag for filtering posts by this creator in Boorusama (`patreon:user:568551`).
  String get searchTag => '$service:user:$id';
}
