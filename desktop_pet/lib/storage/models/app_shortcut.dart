/// Model for a user-defined application launch shortcut.
class AppShortcut {
  final String name;
  final String executablePath;
  final String? hotkey;
  final int order;

  AppShortcut({
    required this.name,
    required this.executablePath,
    this.hotkey,
    required this.order,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'executablePath': executablePath,
    'hotkey': hotkey,
    'order': order,
  };

  factory AppShortcut.fromJson(Map<String, dynamic> json) {
    return AppShortcut(
      name: json['name'] as String,
      executablePath: json['executablePath'] as String,
      hotkey: json['hotkey'] as String?,
      order: json['order'] as int,
    );
  }
}
