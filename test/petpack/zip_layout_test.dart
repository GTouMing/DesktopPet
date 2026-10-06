import 'package:desktop_pet/petpack/import/zip_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeZipEntryName 反斜杠归一、拒绝空名与越界路径', () {
    expect(normalizeZipEntryName(r'live2d-cat\pet.json'), 'live2d-cat/pet.json');
    expect(normalizeZipEntryName('a/0.png'), 'a/0.png');

    expect(normalizeZipEntryName(''), isNull);
    expect(normalizeZipEntryName('/abs/pet.json'), isNull);
    expect(normalizeZipEntryName('../evil'), isNull);
    expect(normalizeZipEntryName('a/../b'), isNull);
  });

  test('singleRootPrefix 剥掉单一顶层目录', () {
    expect(
      singleRootPrefix([
        'live2d-cat/pet.json',
        'live2d-cat/cat.model3.json',
        'live2d-cat/cat.8192/texture_00.png',
      ]),
      'live2d-cat/',
    );
  });

  test('singleRootPrefix 清单已在根目录时不剥', () {
    expect(singleRootPrefix(['pet.json', 'idle/0.png']), '');
  });

  test('singleRootPrefix 多顶层目录/单文件/空列表不剥', () {
    expect(singleRootPrefix(['a/pet.json', 'b/extra.txt']), '');
    expect(singleRootPrefix(['pet.json']), '');
    expect(singleRootPrefix(const []), '');
  });
}
