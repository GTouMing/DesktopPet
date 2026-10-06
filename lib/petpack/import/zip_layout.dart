/// ZIP 解压的条目路径处理（纯函数，便于单测）。
///
/// 导入宠物包时 ZIP 有两种常见布局：
/// - 清单 `pet.json` 就在 zip 根目录；
/// - 整包被多套了一层同名目录（把 `live2d-cat/` 整个压进去），清单落在那一层之下。
///
/// 后者若原样解压，`pet.json` 就不在解压根目录，校验会以 "pet.json not found"
/// 失败——所以解压前先算出"单一顶层目录"前缀并剥掉。
library;

/// 规范化一个 ZIP 条目名：`\` → `/`；空名 / 绝对路径 / 含 `..` 的越界路径返回 null。
///
/// 规范用 `/` 分隔，但存在不守规范的打包器（如 .NET 的 Compress-Archive）会写 `\`。
/// Windows 恰好把 `\` 也当分隔符，于是在 Windows 上「看起来能用」；到 Android/Linux
/// 就会解出一个名字里带反斜杠的单文件，后续校验与模型加载全都找不到。
String? normalizeZipEntryName(String raw) {
  final name = raw.replaceAll('\\', '/');
  if (name.isEmpty || name.startsWith('/') || name.split('/').contains('..')) {
    return null;
  }
  return name;
}

/// 若 [names]（已规范化的条目名）**全部**位于同一个顶层目录之下，返回该前缀
/// （含末尾 `/`）；否则返回 `''`。
///
/// 用于剥掉"整包再套一层目录"的包装层：
/// `['live2d-cat/pet.json', ...]` → `'live2d-cat/'`；
/// `['pet.json', 'idle/0.png']`（清单已在根目录，首项不含 `/`）→ `''`。
String singleRootPrefix(Iterable<String> names) {
  final list = names.toList();
  if (list.isEmpty) return '';
  final slash = list.first.indexOf('/');
  if (slash <= 0) return '';
  final root = list.first.substring(0, slash + 1);
  return list.every((name) => name.startsWith(root)) ? root : '';
}
