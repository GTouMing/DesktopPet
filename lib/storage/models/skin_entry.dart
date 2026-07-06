/// 已安装的皮肤包条目。
class SkinEntry {
  final String name;
  final String folderPath;
  final bool isBuiltIn;
  final DateTime importedAt;

  SkinEntry({
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

  factory SkinEntry.fromJson(Map<String, dynamic> json) {
    return SkinEntry(
      name: json['name'] as String,
      folderPath: json['folderPath'] as String,
      isBuiltIn: json['isBuiltIn'] as bool,
      importedAt: DateTime.fromMillisecondsSinceEpoch(json['importedAt'] as int),
    );
  }
}
