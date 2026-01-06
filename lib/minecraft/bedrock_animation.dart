import 'dart:convert';
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'bedrock_model.dart';

class BedrockAnimationLibrary {
  const BedrockAnimationLibrary({required this.animations});

  final Map<String, BedrockAnimation> animations;

  static BedrockAnimationLibrary? tryParseFromJsonText(String jsonText) {
    final Object? decoded = json.decode(jsonText);
    if (decoded is! Map) {
      return null;
    }
    final Map<String, Object?> root = decoded.cast<String, Object?>();
    final Object? animationsRaw = root['animations'];
    if (animationsRaw is! Map) {
      return null;
    }

    final Map<String, BedrockAnimation> animations = <String, BedrockAnimation>{};
    for (final MapEntry<Object?, Object?> entry in animationsRaw.entries) {
      final Object? key = entry.key;
      final Object? value = entry.value;
      if (key is! String || value is! Map) {
        continue;
      }
      final BedrockAnimation? animation =
          BedrockAnimation.tryParse(key, value.cast<String, Object?>());
      if (animation == null) {
        continue;
      }
      animations[animation.name] = animation;
    }
    return BedrockAnimationLibrary(animations: Map.unmodifiable(animations));
  }
}

class BedrockAnimation {
  const BedrockAnimation({
    required this.name,
    required this.loop,
    required this.lengthSeconds,
    required this.bones,
  });

  final String name;
  final bool loop;
  final double lengthSeconds;
  final Map<String, BedrockBoneAnimation> bones;

  static BedrockAnimation? tryParse(String name, Map<String, Object?> raw) {
    final double length = _toDouble(raw['animation_length']);
    final bool loop = raw['loop'] == true;

    final Map<String, BedrockBoneAnimation> bones = <String, BedrockBoneAnimation>{};
    final Object? bonesRaw = raw['bones'];
    if (bonesRaw is Map) {
      for (final MapEntry<Object?, Object?> boneEntry in bonesRaw.entries) {
        final Object? boneKey = boneEntry.key;
        final Object? boneValue = boneEntry.value;
        if (boneKey is! String || boneValue is! Map) {
          continue;
        }
        final BedrockBoneAnimation? bone = BedrockBoneAnimation.tryParse(
          boneValue.cast<String, Object?>(),
        );
        if (bone == null) {
          continue;
        }
        bones[boneKey] = bone;
      }
    }

    return BedrockAnimation(
      name: name,
      loop: loop,
      lengthSeconds: length,
      bones: Map.unmodifiable(bones),
    );
  }

  Map<String, BedrockBonePose> samplePose(
    BedrockGeometryModel model, {
    required double timeSeconds,
    double? lifeTimeSeconds,
    double targetXRotationDegrees = 0,
    double swimAmount = 1,
  }) {
    final double animationTime = _normalizeTime(timeSeconds);
    final BedrockMolangContext context = BedrockMolangContext(
      lifeTimeSeconds: lifeTimeSeconds ?? timeSeconds,
      targetXRotationDegrees: targetXRotationDegrees,
      swimAmount: swimAmount,
    );

    final Map<String, BedrockBone> bonesByName = <String, BedrockBone>{
      for (final bone in model.bones) bone.name: bone,
    };

    final Map<String, BedrockBonePose> pose = <String, BedrockBonePose>{};
    for (final MapEntry<String, BedrockBoneAnimation> entry in bones.entries) {
      final String boneName = entry.key;
      final BedrockBoneAnimation animation = entry.value;
      final BedrockBone? base = bonesByName[boneName];

      final Vector3 baseRotationBedrock = _boneRotationToBedrock(base?.rotation);
      final Vector3 rotationDeltaBedrock = animation.rotation?.sample(
            animationTime,
            context,
            thisValue: baseRotationBedrock,
          ) ??
          Vector3.zero();
      final Vector3 positionDeltaBedrock = animation.position?.sample(
            animationTime,
            context,
            thisValue: Vector3.zero(),
          ) ??
          Vector3.zero();

      final Vector3 rotation = _bedrockRotationToLocal(rotationDeltaBedrock);
      final Vector3 position = _bedrockPositionToLocal(positionDeltaBedrock);

      if (rotation != Vector3.zero() || position != Vector3.zero()) {
        pose[boneName] = BedrockBonePose(rotation: rotation, position: position);
      }
    }
    return pose;
  }

  double _normalizeTime(double timeSeconds) {
    if (lengthSeconds <= 0) {
      return 0;
    }
    if (loop) {
      final double wrapped = timeSeconds % lengthSeconds;
      return wrapped.isNaN ? 0 : wrapped;
    }
    return timeSeconds.clamp(0, lengthSeconds);
  }
}

class BedrockBoneAnimation {
  const BedrockBoneAnimation({this.rotation, this.position});

  final BedrockAnimatedVec3? rotation;
  final BedrockAnimatedVec3? position;

  static BedrockBoneAnimation? tryParse(Map<String, Object?> raw) {
    final BedrockAnimatedVec3? rotation = BedrockAnimatedVec3.tryParse(raw['rotation']);
    final BedrockAnimatedVec3? position = BedrockAnimatedVec3.tryParse(raw['position']);
    if (rotation == null && position == null) {
      return null;
    }
    return BedrockBoneAnimation(rotation: rotation, position: position);
  }
}

class BedrockAnimatedVec3 {
  const BedrockAnimatedVec3._({this.constant, this.keyframes});

  final _MolangVec3Expr? constant;
  final List<_KeyframeVec3>? keyframes;

  static BedrockAnimatedVec3? tryParse(Object? raw) {
    final _MolangVec3Expr? constant = _MolangVec3Expr.tryParse(raw);
    if (constant != null) {
      return BedrockAnimatedVec3._(constant: constant);
    }
    if (raw is! Map) {
      return null;
    }

    final List<_KeyframeVec3> keyframes = <_KeyframeVec3>[];
    for (final MapEntry<Object?, Object?> entry in raw.entries) {
      final Object? key = entry.key;
      final Object? value = entry.value;
      if (key is! String) {
        continue;
      }
      final double? time = double.tryParse(key.trim());
      if (time == null) {
        continue;
      }
      final _MolangVec3Expr? expr = _MolangVec3Expr.tryParse(value);
      if (expr == null) {
        continue;
      }
      keyframes.add(_KeyframeVec3(time: time, value: expr));
    }
    if (keyframes.isEmpty) {
      return null;
    }
    keyframes.sort((a, b) => a.time.compareTo(b.time));
    return BedrockAnimatedVec3._(keyframes: List.unmodifiable(keyframes));
  }

  Vector3 sample(
    double timeSeconds,
    BedrockMolangContext context, {
    required Vector3 thisValue,
  }) {
    final _MolangVec3Expr? constant = this.constant;
    if (constant != null) {
      return constant.evaluate(context, thisValue: thisValue);
    }

    final List<_KeyframeVec3>? keyframes = this.keyframes;
    if (keyframes == null || keyframes.isEmpty) {
      return Vector3.zero();
    }

    if (keyframes.length == 1) {
      return keyframes.single.value.evaluate(context, thisValue: thisValue);
    }

    _KeyframeVec3? previous;
    _KeyframeVec3? next;
    for (int i = 0; i < keyframes.length; i++) {
      final _KeyframeVec3 frame = keyframes[i];
      if (frame.time <= timeSeconds) {
        previous = frame;
      }
      if (frame.time >= timeSeconds) {
        next = frame;
        break;
      }
    }

    previous ??= keyframes.first;
    next ??= keyframes.last;

    if (previous == next || next.time == previous.time) {
      return previous.value.evaluate(context, thisValue: thisValue);
    }

    final double t = ((timeSeconds - previous.time) / (next.time - previous.time))
        .clamp(0.0, 1.0);
    final Vector3 a = previous.value.evaluate(context, thisValue: thisValue);
    final Vector3 b = next.value.evaluate(context, thisValue: thisValue);
    return Vector3(
      _lerp(a.x, b.x, t),
      _lerp(a.y, b.y, t),
      _lerp(a.z, b.z, t),
    );
  }
}

class BedrockMolangContext {
  const BedrockMolangContext({
    required this.lifeTimeSeconds,
    required this.targetXRotationDegrees,
    required this.swimAmount,
  });

  final double lifeTimeSeconds;
  final double targetXRotationDegrees;
  final double swimAmount;

  double resolveVariable(String name) {
    switch (name) {
      case 'query.life_time':
        return lifeTimeSeconds;
      case 'query.target_x_rotation':
        return targetXRotationDegrees;
      case 'variable.swim_amount':
        return swimAmount;
      case 'math.pi':
      case 'pi':
        return math.pi;
    }
    return 0;
  }
}

class _KeyframeVec3 {
  const _KeyframeVec3({required this.time, required this.value});

  final double time;
  final _MolangVec3Expr value;
}

class _MolangVec3Expr {
  const _MolangVec3Expr(this.x, this.y, this.z);

  final _MolangExpr x;
  final _MolangExpr y;
  final _MolangExpr z;

  static _MolangVec3Expr? tryParse(Object? raw) {
    if (raw is Map) {
      final Map<String, Object?> map = raw.cast<String, Object?>();
      final Object? post = map['post'];
      final Object? pre = map['pre'];
      final _MolangVec3Expr? parsedPost = tryParse(post);
      if (parsedPost != null) {
        return parsedPost;
      }
      final _MolangVec3Expr? parsedPre = tryParse(pre);
      if (parsedPre != null) {
        return parsedPre;
      }
      return null;
    }

    if (raw is! List || raw.length < 3) {
      return null;
    }
    return _MolangVec3Expr(
      _MolangExpr.compile(raw[0]),
      _MolangExpr.compile(raw[1]),
      _MolangExpr.compile(raw[2]),
    );
  }

  Vector3 evaluate(BedrockMolangContext context, {required Vector3 thisValue}) {
    return Vector3(
      x.evaluate(context, thisValue: thisValue.x),
      y.evaluate(context, thisValue: thisValue.y),
      z.evaluate(context, thisValue: thisValue.z),
    );
  }
}

abstract class _MolangExpr {
  const _MolangExpr();

  static final Map<String, _MolangExpr> _cache = <String, _MolangExpr>{};

  static _MolangExpr compile(Object? raw) {
    if (raw is num) {
      return _MolangNumber(raw.toDouble());
    }
    if (raw is String) {
      final String source = raw.trim();
      if (source.isEmpty) {
        return const _MolangNumber(0);
      }
      final _MolangExpr? cached = _cache[source];
      if (cached != null) {
        return cached;
      }
      final _MolangExpr parsed = _MolangParser(source).parse();
      _cache[source] = parsed;
      return parsed;
    }
    return const _MolangNumber(0);
  }

  double evaluate(BedrockMolangContext context, {required double thisValue});
}

class _MolangNumber extends _MolangExpr {
  const _MolangNumber(this.value);

  final double value;

  @override
  double evaluate(BedrockMolangContext context, {required double thisValue}) {
    return value;
  }
}

class _MolangVariable extends _MolangExpr {
  const _MolangVariable(this.name);

  final String name;

  @override
  double evaluate(BedrockMolangContext context, {required double thisValue}) {
    if (name == 'this') {
      return thisValue;
    }
    return context.resolveVariable(name);
  }
}

class _MolangUnary extends _MolangExpr {
  const _MolangUnary(this.op, this.expr);

  final String op;
  final _MolangExpr expr;

  @override
  double evaluate(BedrockMolangContext context, {required double thisValue}) {
    final double v = expr.evaluate(context, thisValue: thisValue);
    switch (op) {
      case '+':
        return v;
      case '-':
        return -v;
    }
    return v;
  }
}

class _MolangBinary extends _MolangExpr {
  const _MolangBinary(this.op, this.left, this.right);

  final String op;
  final _MolangExpr left;
  final _MolangExpr right;

  @override
  double evaluate(BedrockMolangContext context, {required double thisValue}) {
    final double a = left.evaluate(context, thisValue: thisValue);
    final double b = right.evaluate(context, thisValue: thisValue);
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        if (b == 0) return 0;
        return a / b;
    }
    return 0;
  }
}

class _MolangCall extends _MolangExpr {
  const _MolangCall(this.name, this.args);

  final String name;
  final List<_MolangExpr> args;

  @override
  double evaluate(BedrockMolangContext context, {required double thisValue}) {
    final List<double> values = <double>[
      for (final arg in args) arg.evaluate(context, thisValue: thisValue),
    ];

    switch (name) {
      case 'math.sin':
        return _sinDeg(values.isEmpty ? 0 : values[0]);
      case 'math.cos':
        return _cosDeg(values.isEmpty ? 0 : values[0]);
      case 'math.abs':
        return values.isEmpty ? 0 : values[0].abs();
      case 'math.sqrt':
        return values.isEmpty ? 0 : math.sqrt(values[0]);
      case 'math.min':
        if (values.length < 2) return values.isEmpty ? 0 : values[0];
        return math.min(values[0], values[1]);
      case 'math.max':
        if (values.length < 2) return values.isEmpty ? 0 : values[0];
        return math.max(values[0], values[1]);
      case 'math.clamp':
        if (values.length < 3) return values.isEmpty ? 0 : values[0];
        return values[0].clamp(values[1], values[2]);
    }

    return 0;
  }
}

class _MolangParser {
  _MolangParser(this.source) : _lexer = _MolangLexer(source);

  final String source;
  final _MolangLexer _lexer;

  _MolangToken _current = const _MolangToken(_MolangTokenType.eof);

  _MolangExpr parse() {
    _advance();
    final _MolangExpr expr = _parseExpression();
    return expr;
  }

  void _advance() {
    _current = _lexer.nextToken();
  }

  bool _match(_MolangTokenType type) {
    if (_current.type == type) {
      _advance();
      return true;
    }
    return false;
  }

  _MolangExpr _parseExpression() {
    _MolangExpr expr = _parseTerm();
    while (_current.type == _MolangTokenType.plus ||
        _current.type == _MolangTokenType.minus) {
      final String op = _current.lexeme;
      _advance();
      final _MolangExpr right = _parseTerm();
      expr = _MolangBinary(op, expr, right);
    }
    return expr;
  }

  _MolangExpr _parseTerm() {
    _MolangExpr expr = _parseUnary();
    while (_current.type == _MolangTokenType.star ||
        _current.type == _MolangTokenType.slash) {
      final String op = _current.lexeme;
      _advance();
      final _MolangExpr right = _parseUnary();
      expr = _MolangBinary(op, expr, right);
    }
    return expr;
  }

  _MolangExpr _parseUnary() {
    if (_current.type == _MolangTokenType.plus ||
        _current.type == _MolangTokenType.minus) {
      final String op = _current.lexeme;
      _advance();
      final _MolangExpr expr = _parseUnary();
      return _MolangUnary(op, expr);
    }
    return _parsePrimary();
  }

  _MolangExpr _parsePrimary() {
    if (_current.type == _MolangTokenType.number) {
      final double value = _current.numberValue ?? 0;
      _advance();
      return _MolangNumber(value);
    }

    if (_current.type == _MolangTokenType.identifier) {
      final String name = _current.lexeme;
      _advance();
      if (_match(_MolangTokenType.lParen)) {
        final List<_MolangExpr> args = <_MolangExpr>[];
        if (!_match(_MolangTokenType.rParen)) {
          do {
            args.add(_parseExpression());
          } while (_match(_MolangTokenType.comma));
          _match(_MolangTokenType.rParen);
        }
        return _MolangCall(name, List.unmodifiable(args));
      }
      return _MolangVariable(name);
    }

    if (_match(_MolangTokenType.lParen)) {
      final _MolangExpr expr = _parseExpression();
      _match(_MolangTokenType.rParen);
      return expr;
    }

    // Unexpected token, try to recover.
    _advance();
    return const _MolangNumber(0);
  }
}

class _MolangLexer {
  _MolangLexer(this.source);

  final String source;
  int _index = 0;

  _MolangToken nextToken() {
    while (_index < source.length) {
      final String c = source[_index];
      if (_isWhitespace(c)) {
        _index++;
        continue;
      }
      if (_isDigit(c) || c == '.') {
        return _numberToken();
      }
      if (_isIdentStart(c)) {
        return _identifierToken();
      }
      _index++;
      switch (c) {
        case '+':
          return const _MolangToken(_MolangTokenType.plus, lexeme: '+');
        case '-':
          return const _MolangToken(_MolangTokenType.minus, lexeme: '-');
        case '*':
          return const _MolangToken(_MolangTokenType.star, lexeme: '*');
        case '/':
          return const _MolangToken(_MolangTokenType.slash, lexeme: '/');
        case '(':
          return const _MolangToken(_MolangTokenType.lParen, lexeme: '(');
        case ')':
          return const _MolangToken(_MolangTokenType.rParen, lexeme: ')');
        case ',':
          return const _MolangToken(_MolangTokenType.comma, lexeme: ',');
      }
      return const _MolangToken(_MolangTokenType.unknown);
    }
    return const _MolangToken(_MolangTokenType.eof);
  }

  _MolangToken _numberToken() {
    final int start = _index;
    bool hasDot = false;
    while (_index < source.length) {
      final String c = source[_index];
      if (_isDigit(c)) {
        _index++;
        continue;
      }
      if (c == '.' && !hasDot) {
        hasDot = true;
        _index++;
        continue;
      }
      break;
    }
    final String lexeme = source.substring(start, _index);
    return _MolangToken(
      _MolangTokenType.number,
      lexeme: lexeme,
      numberValue: double.tryParse(lexeme),
    );
  }

  _MolangToken _identifierToken() {
    final int start = _index;
    while (_index < source.length) {
      final String c = source[_index];
      if (_isIdentPart(c)) {
        _index++;
        continue;
      }
      break;
    }
    final String lexeme = source.substring(start, _index);
    return _MolangToken(_MolangTokenType.identifier, lexeme: lexeme);
  }

  bool _isWhitespace(String c) =>
      c == ' ' || c == '\t' || c == '\n' || c == '\r';

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  bool _isIdentStart(String c) {
    final int code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        c == '_';
  }

  bool _isIdentPart(String c) => _isIdentStart(c) || _isDigit(c) || c == '.';
}

enum _MolangTokenType {
  number,
  identifier,
  plus,
  minus,
  star,
  slash,
  comma,
  lParen,
  rParen,
  unknown,
  eof,
}

class _MolangToken {
  const _MolangToken(this.type, {this.lexeme = '', this.numberValue});

  final _MolangTokenType type;
  final String lexeme;
  final double? numberValue;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _sinDeg(double degrees) => math.sin(degrees * (math.pi / 180.0));

double _cosDeg(double degrees) => math.cos(degrees * (math.pi / 180.0));

Vector3 _boneRotationToBedrock(Vector3? localRotation) {
  if (localRotation == null) {
    return Vector3.zero();
  }
  return Vector3(-localRotation.x, -localRotation.y, localRotation.z);
}

Vector3 _bedrockRotationToLocal(Vector3 bedrockRotation) {
  return Vector3(-bedrockRotation.x, -bedrockRotation.y, bedrockRotation.z);
}

Vector3 _bedrockPositionToLocal(Vector3 bedrockPosition) {
  return Vector3(-bedrockPosition.x, bedrockPosition.y, bedrockPosition.z);
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}
