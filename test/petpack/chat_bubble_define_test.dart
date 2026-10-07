import 'package:desktop_pet/petpack/chat_bubble_content.dart';
import 'package:desktop_pet/petpack/pet_pack.dart';
import 'package:desktop_pet/petpack/state/state_define.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bubbles 命名池：文本/图片/时长/摆放都解析，空项与非对象项跳过', () {
    final bubbles = parsePetPackBubbles(<String, dynamic>{
      'bubbles': <String, dynamic>{
        'greeting': <String, dynamic>{
          'text': '你好呀～',
          'durationMs': 4000,
          'placement': 'top',
        },
        'wave': <String, dynamic>{'image': 'bubble/wave.png'},
        'both': <String, dynamic>{
          'text': '记得喝水',
          'image': 'bubble/water.png',
          'maxWidth': 200,
          'placement': 'left',
        },
        'empty': <String, dynamic>{'foo': 1},
        'bad': 'nope',
      },
    });

    expect(bubbles.keys, containsAll(['greeting', 'wave', 'both']));
    expect(bubbles.containsKey('empty'), isFalse);
    expect(bubbles.containsKey('bad'), isFalse);

    expect(bubbles['greeting']!.text, '你好呀～');
    expect(bubbles['greeting']!.durationMs, 4000);
    expect(bubbles['greeting']!.placement, BubblePlacement.top);
    expect(bubbles['greeting']!.image, isNull);

    expect(bubbles['wave']!.image, 'bubble/wave.png');
    expect(bubbles['wave']!.text, isNull);

    expect(bubbles['both']!.maxWidth, 200);
    expect(bubbles['both']!.placement, BubblePlacement.left);
  });

  test('bubbles 缺失或非对象：返回空表', () {
    expect(parsePetPackBubbles(<String, dynamic>{}), isEmpty);
    expect(parsePetPackBubbles(<String, dynamic>{'bubbles': 'nope'}), isEmpty);
  });

  test('内容解析：非法 placement 回 auto，isEmpty 按文本与图片判定', () {
    expect(
      ChatBubbleContent.fromJson(<String, dynamic>{
        'text': 'a',
        'placement': 'wat',
      }).placement,
      BubblePlacement.auto,
    );
    expect(
      ChatBubbleContent.fromJson(<String, dynamic>{'text': 'a'}).placement,
      BubblePlacement.auto,
    );

    expect(const ChatBubbleContent().isEmpty, isTrue);
    expect(const ChatBubbleContent(text: '').isEmpty, isTrue);
    expect(const ChatBubbleContent(image: '').isEmpty, isTrue);
    expect(const ChatBubbleContent(text: 'a').isEmpty, isFalse);
    expect(const ChatBubbleContent(image: 'a.png').isEmpty, isFalse);
  });

  test('copyWith：非空参数覆盖，null 保留原值', () {
    const base = ChatBubbleContent(
      text: 'hi',
      durationMs: 1000,
      placement: BubblePlacement.top,
    );
    final merged = base.copyWith(text: 'yo', maxWidth: 200);

    expect(merged.text, 'yo');
    expect(merged.maxWidth, 200);
    expect(merged.durationMs, 1000);
    expect(merged.placement, BubblePlacement.top);
  });

  test('StateDef.bubble：解析引用；空串与缺失都归 null', () {
    expect(
      StateDef.fromJson('s', <String, dynamic>{
        'animation': 'Idle',
        'bubble': 'greeting',
      }).bubble,
      'greeting',
    );
    expect(
      StateDef.fromJson('s', <String, dynamic>{'bubble': '   '}).bubble,
      isNull,
    );
    expect(StateDef.fromJson('s', <String, dynamic>{}).bubble, isNull);
  });
}
