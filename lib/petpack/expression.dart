import 'dart:math';

/// 用于动画变换的轻量级数学表达式评估器。
/// 支持：+ - * / ^ ( )，数字，PI，t（归一化时间0→1）
/// 函数：sin， cos， abs， clamp（a， b， c）， lerp（a， b， t）
double evalExpr(String expr, {double t = 0}) {
  return _Parser(expr, t).parseExpression();
}

class _Parser {
  final String _src;
  final double _t;
  int _pos = 0;

  _Parser(this._src, this._t);

  void _skipWs() {
    while (_pos < _src.length && _src[_pos] == ' ') {
      _pos++;
    }
  }

  bool _eof() => _pos >= _src.length;

  int _peek() => _eof() ? 0 : _src.codeUnitAt(_pos);

  void _expect(String s) {
    for (int i = 0; i < s.length; i++) {
      if (_pos + i >= _src.length || _src[_pos + i] != s[i]) {
        throw FormatException('Expected "$s" at $_pos in "$_src"');
      }
    }
    _pos += s.length;
  }

  double parseExpression() {
    double v = parseTerm();
    while (!_eof()) {
      _skipWs();
      if (_peek() == '+'.codeUnitAt(0)) {
        _pos++;
        v += parseTerm();
      } else if (_peek() == '-'.codeUnitAt(0)) {
        _pos++;
        v -= parseTerm();
      } else {
        break;
      }
    }
    return v;
  }

  double parseTerm() {
    double v = parseFactor();
    while (!_eof()) {
      _skipWs();
      if (_peek() == '*'.codeUnitAt(0)) {
        _pos++;
        v *= parseFactor();
      } else if (_peek() == '/'.codeUnitAt(0)) {
        _pos++;
        v /= parseFactor();
      } else {
        break;
      }
    }
    return v;
  }

  double parseFactor() {
    _skipWs();
    if (_peek() == '-'.codeUnitAt(0)) {
      _pos++;
      return -parseFactor();
    }
    return parseAtom();
  }

  double parseAtom() {
    _skipWs();
    if (_eof()) throw FormatException('Unexpected end at $_pos');

    if (_isDigit(_src[_pos]) || _src[_pos] == '.') {
      return parseNumber();
    }

    if (_src[_pos] == '(') {
      _pos++;
      double val = parseExpression();
      _skipWs();
      _expect(')');
      return val;
    }

    if (_src.startsWith('PI', _pos)) {
      _pos += 2;
      return pi;
    }

    if (_src[_pos] == 't' && (_pos + 1 >= _src.length || !_isLetterOrDigit(_src[_pos + 1]))) {
      _pos++;
      return _t;
    }

    if (_isLetter(_src[_pos])) {
      return parseFunction();
    }

    throw FormatException('Unexpected char "${_src[_pos]}" at $_pos');
  }

  double parseNumber() {
    int start = _pos;
    while (_pos < _src.length && (_isDigit(_src[_pos]) || _src[_pos] == '.')) {
      _pos++;
    }
    return double.parse(_src.substring(start, _pos));
  }

  double parseFunction() {
    int start = _pos;
    while (_pos < _src.length && _isLetterOrDigit(_src[_pos])) {
      _pos++;
    }
    final name = _src.substring(start, _pos);
    _skipWs();
    _expect('(');
    final args = <double>[];
    args.add(parseExpression());
    _skipWs();
    while (_peek() == ','.codeUnitAt(0)) {
      _pos++;
      args.add(parseExpression());
      _skipWs();
    }
    _expect(')');

    switch (name) {
      case 'sin': return sin(_arg(args, 0));
      case 'cos': return cos(_arg(args, 0));
      case 'abs': return _arg(args, 0).abs();
      case 'clamp': return _arg(args, 0).clamp(_arg(args, 1), _arg(args, 2));
      case 'lerp': return _arg(args, 0) + (_arg(args, 1) - _arg(args, 0)) * _arg(args, 2);
      default: throw FormatException('Unknown function: $name');
    }
  }

  double _arg(List<double> a, int i) => i < a.length ? a[i] : 0;

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  bool _isLetter(String c) => (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) || (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122);
  bool _isLetterOrDigit(String c) => _isLetter(c) || _isDigit(c);
}