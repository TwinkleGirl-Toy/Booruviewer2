class PawchiveTagDto {
  const PawchiveTagDto({
    required this.name,
    this.count,
    this.category,
  });

  final String name;
  final int? count;
  final String? category;

  String get normalizedName =>
      name.trim().replaceAll(RegExp(r'\s+'), '_');
}
