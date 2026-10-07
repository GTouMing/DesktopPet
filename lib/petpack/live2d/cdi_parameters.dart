import 'dart:convert';
import 'dart:io';

import '../live2d_pet_pack.dart';

/// 一个 Live2D 模型参数的清单条目，读自包的 `cdi3.json`。
///
/// 只用于**编辑页列出参数**（id + 显示名 + 分组）；运行时的 `min/max/default`
/// 由原生快照（`Live2DChannel.getModelInfo`）提供。
class L2dModelParameter {
  const L2dModelParameter({
    required this.id,
    required this.name,
    required this.groupId,
  });

  /// 参数 id（如 `ParamAngleX`）。
  final String id;

  /// 显示名（cdi3 里作者写的中文名；缺失时回退 [id]）。
  final String name;

  /// cdi3 里的分组 id（`GroupId`，可为空串 = 未分组）。
  final String groupId;
}

/// 一个模型的参数清单 + 分组名。
class CdiParameters {
  const CdiParameters({required this.parameters, required this.groupNames});

  final List<L2dModelParameter> parameters;

  /// 分组 id → 分组名（cdi3 `ParameterGroups`）。
  final Map<String, String> groupNames;

  bool get isEmpty => parameters.isEmpty;

  static const CdiParameters empty =
      CdiParameters(parameters: [], groupNames: {});
}

/// 读 [pack] 的模型参数清单：
/// `model3.json` 的 `FileReferences.DisplayInfo` → `*.cdi3.json` 的
/// `Parameters[*]`（Id/Name/GroupId）与 `ParameterGroups`（Id/Name）。
///
/// 任一步骤缺失/解析失败都返回 [CdiParameters.empty]——编辑页据此不显示
/// 「跟随参数」区，不影响其余功能。
Future<CdiParameters> loadModelParameters(Live2DPetPack pack) async {
  try {
    final modelFile = File('${pack.basePath}/${pack.modelFileName}');
    if (!await modelFile.exists()) return CdiParameters.empty;
    final modelJson = jsonDecode(await modelFile.readAsString());
    if (modelJson is! Map) return CdiParameters.empty;

    final refs = modelJson['FileReferences'];
    final displayInfo = refs is Map ? refs['DisplayInfo'] : null;
    if (displayInfo is! String || displayInfo.isEmpty) {
      return CdiParameters.empty;
    }

    final cdiFile = File('${pack.basePath}/$displayInfo');
    if (!await cdiFile.exists()) return CdiParameters.empty;
    final cdiJson = jsonDecode(await cdiFile.readAsString());
    if (cdiJson is! Map) return CdiParameters.empty;

    final groupNames = <String, String>{};
    final rawGroups = cdiJson['ParameterGroups'];
    if (rawGroups is List) {
      for (final item in rawGroups) {
        if (item is! Map) continue;
        final id = item['Id'];
        final name = item['Name'];
        if (id is String && id.isNotEmpty && name is String && name.isNotEmpty) {
          groupNames[id] = name;
        }
      }
    }

    final rawParameters = cdiJson['Parameters'];
    if (rawParameters is! List) return CdiParameters.empty;

    final parameters = <L2dModelParameter>[];
    for (final item in rawParameters) {
      if (item is! Map) continue;
      final id = item['Id'];
      if (id is! String || id.isEmpty) continue;
      final name = item['Name'];
      final groupId = item['GroupId'];
      parameters.add(L2dModelParameter(
        id: id,
        name: (name is String && name.isNotEmpty) ? name : id,
        groupId: groupId is String ? groupId : '',
      ));
    }
    return CdiParameters(parameters: parameters, groupNames: groupNames);
  } catch (_) {
    return CdiParameters.empty;
  }
}
