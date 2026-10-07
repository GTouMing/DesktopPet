import 'package:desktop_pet/petpack/state/state_define.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('状态参数集：字符串与 bool 解析为 label，非法项跳过', () {
    final def = StateDef.fromJson('happy', <String, dynamic>{
      'animation': 'Idle',
      'params': <String, dynamic>{
        'expression': '放松',
        'question': true,
        'ear': false,
        'bad': 3,
        '': 'x',
      },
    });

    expect(def.params, {'expression': '放松', 'question': 'on', 'ear': 'off'});
    expect(def.animation, 'Idle');
  });

  test('animation 可省略（参数驱动的状态），transitions 照常解析', () {
    final def = StateDef.fromJson('sleepy', <String, dynamic>{
      'params': <String, dynamic>{'expression': '昏迷'},
      'transitions': <String, dynamic>{
        'idle': <String, dynamic>{
          'click': <String, dynamic>{},
          'waitTimer': <String, dynamic>{'afterMs': 2000},
        },
      },
    });

    expect(def.animation, '');
    expect(def.params, {'expression': '昏迷'});
    expect(def.transitions.keys, ['idle']);
    expect(def.transitions['idle']!.keys, containsAll(['click', 'waitTimer']));
    expect(def.transitions['idle']!['waitTimer']!.afterMs, 2000);
  });

  test('time / hold：标量与对象两种写法都能解析', () {
    final def = StateDef.fromJson('idle', <String, dynamic>{
      'animation': 'Idle',
      'transitions': <String, dynamic>{
        'morning': <String, dynamic>{'time': '09:00:00'},
        'night': <String, dynamic>{
          'time': <String, dynamic>{'at': '23:59:59'},
        },
        'work': <String, dynamic>{
          'time': <String, dynamic>{
            'at': <String>['09:00:00', '14:00:00'],
          },
        },
        'pet': <String, dynamic>{'hold': 500},
        'pet2': <String, dynamic>{
          'hold': <String, dynamic>{'holdMs': 1200},
        },
      },
    });

    expect(def.transitions['morning']!['time']!.at, ['09:00:00']);
    expect(def.transitions['morning']!['time']!.atSeconds, [9 * 3600]);
    expect(def.transitions['night']!['time']!.atSeconds,
        [23 * 3600 + 59 * 60 + 59]);
    // 数组时刻：多个时刻都解析出来。
    expect(def.transitions['work']!['time']!.at, ['09:00:00', '14:00:00']);
    expect(def.transitions['work']!['time']!.atSeconds, [9 * 3600, 14 * 3600]);
    expect(def.transitions['pet']!['hold']!.holdMs, 500);
    expect(def.transitions['pet2']!['hold']!.holdMs, 1200);
  });

  test('time：非法时刻被忽略（越界/缺项/非数字）', () {
    List<int> seconds(Object value) => StateDef.fromJson('s', <String, dynamic>{
          'transitions': <String, dynamic>{
            't': <String, dynamic>{'time': value},
          },
        }).transitions['t']!['time']!.atSeconds;

    expect(seconds('09:00:00'), [32400]);
    expect(seconds('24:00:00'), isEmpty);
    expect(seconds('09:60:00'), isEmpty);
    expect(seconds('09:00'), isEmpty);
    expect(seconds('abc'), isEmpty);
    // 数组里混入非法项：只保留合法的。
    expect(seconds(<String>['09:00:00', '25:00:00']), [32400]);
    expect(seconds(<String>['bad']), isEmpty);
  });
}
