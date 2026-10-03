/// Model for a user-defined application launch shortcut.
class AppShortcut {
  final String name;
  final String executablePath;
  final int order;

  AppShortcut({
    required this.name,
    required this.executablePath,
    required this.order,
  });

  /// 按列表当前顺序重新编号 [order]（增删/重排后调用）。
  static List<AppShortcut> reindexed(List<AppShortcut> shortcuts) => [
    for (var i = 0; i < shortcuts.length; i++)
      AppShortcut(
        name: shortcuts[i].name,
        executablePath: shortcuts[i].executablePath,
        order: i,
      ),
  ];

  Map<String, dynamic> toJson() => {
    'name': name,
    'executablePath': executablePath,
    'order': order,
  };

  factory AppShortcut.fromJson(Map<String, dynamic> json) {
    return AppShortcut(
      name: json['name'] as String,
      executablePath: json['executablePath'] as String,
      order: json['order'] as int,
    );
  }
}
