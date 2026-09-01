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
