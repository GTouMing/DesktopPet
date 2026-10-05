import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../petpack/pet_pack_lister.dart';
import '../../storage/storage_service.dart';

/// 宠物包选择屏幕。
class PetPackPickerScreen extends StatefulWidget {
  const PetPackPickerScreen({super.key});

  @override
  State<PetPackPickerScreen> createState() => _PetPackPickerScreenState();
}

class _PetPackPickerScreenState extends State<PetPackPickerScreen> {
  List<DiscoveredPetPack>? _packs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  Future<void> _loadPacks() async {
    try {
      final packs = await PetPackLister.listAvailable();
      if (!mounted) return;
      setState(() => _packs = packs);
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
      appBar: AppBar(title: Text(l10n.choosePetPackTitle), centerTitle: true),
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
            Text(l10n.loadPetPacksFailed, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _packs = null;
                    _error = null;
                  });
                  _loadPacks();
                },
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry)),
          ]),
        ),
      );
    }

    if (_packs == null) return const Center(child: CircularProgressIndicator());

    if (_packs!.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.folder_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(l10n.noPetPacksFound, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.noPetPacksFoundHint,
              style: TextStyle(color: Colors.grey[500])),
        ]),
      );
    }

    final packDir = _getPackDir();
    final isDefault = PetPackLister.isDefaultPath(packDir);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
              isDefault
                  ? l10n.petPackSourceImported
                  : l10n.petPackSourceDir('$packDir'),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _packs!.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final pack = _packs![index];
              return _PetPackTile(pack: pack, onTap: () => Navigator.pop(context, pack.path));
            },
          ),
        ),
      ],
    );
  }

  String? _getPackDir() {
    try {
      return StorageService.readSettings().packDir;
    } catch (_) {
      return null;
    }
  }
}

class _PetPackTile extends StatelessWidget {
  final DiscoveredPetPack pack;
  final VoidCallback onTap;
  const _PetPackTile({required this.pack, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: pack.isBuiltIn ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[100],
        child: Icon(pack.isBuiltIn ? Icons.auto_awesome : Icons.folder_open, color: pack.isBuiltIn ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.grey[600]),
      ),
      title: Row(children: [
        Flexible(child: Text(pack.name, overflow: TextOverflow.ellipsis)),
        if (pack.isBuiltIn) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(4)), child: Text(l10n.builtIn, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onPrimaryContainer)))],
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            pack.type == PetPackType.live2d
                ? l10n.petPackTypeLive2d
                : l10n.petPackTypeSprite,
            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
          ),
        ),
      ]),
      subtitle: Text(pack.path, overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
