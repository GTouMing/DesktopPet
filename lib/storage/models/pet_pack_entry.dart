/// 已安装的皮肤包条目。
class PetPackEntry {
  final String name;
  final String folderPath;
  final bool isBuiltIn;
  final DateTime importedAt;

  PetPackEntry({
    required this.name,
    required this.folderPath,
    required this.isBuiltIn,
    required this.importedAt,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'folderPath': folderPath,
    'isBuiltIn': isBuiltIn,
    'importedAt': importedAt.millisecondsSinceEpoch,
  };

  factory PetPackEntry.fromJson(Map<String, dynamic> json) {
    return PetPackEntry(
      name: json['name'] as String,
      folderPath: json['folderPath'] as String,
      isBuiltIn: json['isBuiltIn'] as bool,
      importedAt: DateTime.fromMillisecondsSinceEpoch(json['importedAt'] as int),
    );
  }
}
