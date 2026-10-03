import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../skin/skin_lister.dart';
import '../../storage/storage_service.dart';

/// 皮肤包选择屏幕。
class SkinPickerScreen extends StatefulWidget {
  const SkinPickerScreen({super.key});

  @override
  State<SkinPickerScreen> createState() => _SkinPickerScreenState();
}

class _SkinPickerScreenState extends State<SkinPickerScreen> {
  List<DiscoveredSkin>? _skins;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSkins();
  }

  Future<void> _loadSkins() async {
    try {
      final skins = await SkinLister.listAvailable();
      if (!mounted) return;
      setState(() => _skins = skins);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: Text(l10n.chooseSkinTitle), centerTitle: true),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(l10n.loadSkinsFailed, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _skins = null;
                    _error = null;
                  });
                  _loadSkins();
                },
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry)),
          ]),
        ),
      );
    }

    if (_skins == null) return const Center(child: CircularProgressIndicator());

    if (_skins!.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.folder_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(l10n.noSkinsFound, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.noSkinsFoundHint,
              style: TextStyle(color: Colors.grey[500])),
        ]),
      );
    }

    final skinDir = _getSkinDir();
    final isDefault = SkinLister.isDefaultPath(skinDir);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
              isDefault
                  ? l10n.skinSourceImported
                  : l10n.skinSourceDir('$skinDir'),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _skins!.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final skin = _skins![index];
              return _SkinTile(skin: skin, onTap: () => Navigator.pop(context, skin.path));
            },
          ),
        ),
      ],
    );
  }

  String? _getSkinDir() {
    try {
      return StorageService.readSettings().skinDir;
    } catch (_) {
      return null;
    }
  }
}

class _SkinTile extends StatelessWidget {
  final DiscoveredSkin skin;
  final VoidCallback onTap;
  const _SkinTile({required this.skin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: skin.isBuiltIn ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[100],
        child: Icon(skin.isBuiltIn ? Icons.auto_awesome : Icons.folder_open, color: skin.isBuiltIn ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.grey[600]),
      ),
      title: Row(children: [
        Flexible(child: Text(skin.name, overflow: TextOverflow.ellipsis)),
        if (skin.isBuiltIn) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(4)), child: Text(l10n.builtIn, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onPrimaryContainer)))],
      ]),
      subtitle: Text(skin.path, overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
