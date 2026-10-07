import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../petpack/pet_pack_lister.dart';
import '../../storage/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_plate.dart';
import '../widgets/section_panel.dart';

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

  void _retry() {
    setState(() {
      _packs = null;
      _error = null;
    });
    _loadPacks();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: Text(l10n.choosePetPackTitle)),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_error != null) {
      return _MessagePanel(
        icon: Icons.error_outline_rounded,
        tone: PlateTone.danger,
        title: l10n.loadPetPacksFailed,
        message: _error!,
        action: FilledButton.icon(
          onPressed: _retry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(l10n.retry),
        ),
      );
    }

    if (_packs == null) {
      // 命名正在做的事，而不是丢一个没有文字的转圈——读屏用户对后者一无所知。
      return Center(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: Insets.lg),
              Text(l10n.loadingPetPacks),
            ],
          ),
        ),
      );
    }

    if (_packs!.isEmpty) {
      return _MessagePanel(
        icon: Icons.folder_off_rounded,
        tone: PlateTone.neutral,
        title: l10n.noPetPacksFound,
        message: l10n.noPetPacksFoundHint,
      );
    }

    final packDir = _getPackDir();
    final isDefault = PetPackLister.isDefaultPath(packDir);
    final source = isDefault
        ? l10n.petPackSourceImported
        : l10n.petPackSourceDir(packDir ?? '');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.md, Insets.lg, Insets.xxl),
      children: [
        _SourceLine(text: source),
        const SizedBox(height: Insets.lg),
        SectionPanel(
          child: Column(
            children: [
              for (var i = 0; i < _packs!.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _PetPackTile(
                  pack: _packs![i],
                  onTap: () => Navigator.pop(context, _packs![i].path),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
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

/// 来源说明：这一列表是从哪个目录/来源读出来的。
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(Icons.folder_rounded, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PetPackTile extends StatelessWidget {
  const _PetPackTile({required this.pack, required this.onTap});

  final DiscoveredPetPack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      onTap: onTap,
      leading: IconPlate(
        icon: pack.isBuiltIn
            ? Icons.auto_awesome_rounded
            : Icons.folder_open_rounded,
        tone: pack.isBuiltIn ? PlateTone.accent : PlateTone.neutral,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(pack.name, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: Insets.sm),
          if (pack.isBuiltIn) ...[
            _Tag(label: l10n.builtIn, accent: true),
            const SizedBox(width: 6),
          ],
          _Tag(
            label: pack.type == PetPackType.live2d
                ? l10n.petPackTypeLive2d
                : l10n.petPackTypeSprite,
          ),
        ],
      ),
      subtitle: Text(
        pack.path,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// 小标签：类型、内置等。
class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: accent
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: accent ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 居中的说明面板：错误与空状态共用。
class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final PlateTone tone;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.lg, Insets.lg, Insets.xxl),
      children: [
        SectionPanel(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.xl, vertical: Insets.xxl),
            child: Column(
              children: [
                IconPlate(icon: icon, tone: tone, size: 56, iconSize: 26),
                const SizedBox(height: Insets.lg),
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  message,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (action != null) ...[
                  const SizedBox(height: Insets.xl),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
