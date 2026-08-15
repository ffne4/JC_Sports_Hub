// Generates the JC Sports Hub launcher icon (replaces the default Flutter
// icon). Run with:  dart run tool/generate_icon.dart
//
// It renders a green sports-ball icon and writes correctly-sized PNGs into
// android/app/src/main/res/mipmap-*/ic_launcher.png.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int _master = 1024;
late Uint8List _px = Uint8List(_master * _master * 4);

void _set(int x, int y, int r, int g, int b, int a) {
  if (x < 0 || y < 0 || x >= _master || y >= _master) return;
  final i = (y * _master + x) * 4;
  _px[i] = r;
  _px[i + 1] = g;
  _px[i + 2] = b;
  _px[i + 3] = a;
}

void _fillCircle(int cx, int cy, int radius, int r, int g, int b, int a) {
  for (int y = cy - radius; y <= cy + radius; y++) {
    for (int x = cx - radius; x <= cx + radius; x++) {
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy <= radius * radius) _set(x, y, r, g, b, a);
    }
  }
}

void _drawThickLine(
    int x0, int y0, int x1, int y1, int w, int r, int g, int b, int a) {
  final steps = max(
      1,
      (sqrt(pow(x1 - x0, 2) + pow(y1 - y0, 2)) / 2).round());
  for (int s = 0; s <= steps; s++) {
    final t = s / steps;
    final x = (x0 + (x1 - x0) * t).round();
    final y = (y0 + (y1 - y0) * t).round();
    _fillCircle(x, y, w ~/ 2, r, g, b, a);
  }
}

void _fillRoundedRect(int left, int top, int right, int bottom, int corner,
    int r, int g, int b, int a) {
  for (int y = top; y <= bottom; y++) {
    for (int x = left; x <= right; x++) {
      final inCornerTL = x < left + corner && y < top + corner;
      final inCornerTR = x > right - corner && y < top + corner;
      final inCornerBL = x < left + corner && y > bottom - corner;
      final inCornerBR = x > right - corner && y > bottom - corner;
      bool ok = true;
      if (inCornerTL) {
        ok = (x - (left + corner)) * (x - (left + corner)) +
                (y - (top + corner)) * (y - (top + corner)) <=
            corner * corner;
      } else if (inCornerTR) {
        ok = (x - (right - corner)) * (x - (right - corner)) +
                (y - (top + corner)) * (y - (top + corner)) <=
            corner * corner;
      } else if (inCornerBL) {
        ok = (x - (left + corner)) * (x - (left + corner)) +
                (y - (bottom - corner)) * (y - (bottom - corner)) <=
            corner * corner;
      } else if (inCornerBR) {
        ok = (x - (right - corner)) * (x - (right - corner)) +
                (y - (bottom - corner)) * (y - (bottom - corner)) <=
            corner * corner;
      }
      if (ok) _set(x, y, r, g, b, a);
    }
  }
}

void _render() {
  // Rounded green background with padding so it survives any launcher mask.
  _fillRoundedRect(0, 0, _master - 1, _master - 1, 180, 27, 94, 32, 255);

  // Subtle darker green ring for depth.
  final cx = _master ~/ 2;
  final cy = _master ~/ 2;
  for (int i = 0; i < 40; i++) {
    _fillCircle(cx, cy, 330 + i, 18, 72, 26, 255);
  }

  // White sports ball.
  final ballR = 280;
  _fillCircle(cx, cy, ballR, 255, 255, 255, 255);

  // Football seams - a central pentagon with lines radiating to the rim.
  final pent = 95;
  final points = <(int, int)>[];
  for (int i = 0; i < 5; i++) {
    final ang = -pi / 2 + i * 2 * pi / 5;
    points.add((
      (cx + pent * cos(ang)).round(),
      (cy + pent * sin(ang)).round()
    ));
  }
  for (int i = 0; i < 5; i++) {
    final p0 = points[i];
    final p1 = points[(i + 1) % 5];
    _drawThickLine(p0.$1, p0.$2, p1.$1, p1.$2, 26, 24, 58, 34, 255);
  }
  for (int i = 0; i < 5; i++) {
    final p0 = points[i];
    final ang = -pi / 2 + i * 2 * pi / 5;
    final ex = (cx + ballR * cos(ang)).round();
    final ey = (cy + ballR * sin(ang)).round();
    _drawThickLine(p0.$1, p0.$2, ex, ey, 26, 24, 58, 34, 255);
  }
  // Short curved seams near the rim.
  for (int i = 0; i < 5; i++) {
    final base = -pi / 2 + (i * 2 * pi / 5) + pi / 5;
    int? px0, py0;
    for (int t = 0; t <= 18; t++) {
      final ang = base - 0.35 + t / 18 * 0.7;
      final x = (cx + ballR * 0.96 * cos(ang)).round();
      final y = (cy + ballR * 0.96 * sin(ang)).round();
      if (px0 != null) {
        _drawThickLine(px0, py0!, x, y, 14, 24, 58, 34, 255);
      }
      px0 = x;
      py0 = y;
    }
  }
}
Uint8List _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b;
    for (int k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  final out = ByteData(4);
  out.setUint32(0, crc ^ 0xFFFFFFFF);
  return out.buffer.asUint8List();
}

Uint8List _chunk(String type, Uint8List data) {
  final len = ByteData(4)..setUint32(0, data.length);
  final t = Uint8List.fromList(type.codeUnits);
  final body = <int>[...t, ...data];
  final crc = _crc32(Uint8List.fromList(body));
  return Uint8List.fromList([...len.buffer.asUint8List(), ...body, ...crc]);
}

Uint8List _pngEncode(Uint8List rgba, int w, int h) {
  final out = BytesBuilder();
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final ihdr = ByteData(13);
  ihdr.setUint32(0, w);
  ihdr.setUint32(4, h);
  ihdr.setUint8(8, 8);
  ihdr.setUint8(9, 6); // RGBA
  ihdr.setUint8(10, 0);
  ihdr.setUint8(11, 0);
  ihdr.setUint8(12, 0);
  out.add(_chunk('IHDR', ihdr.buffer.asUint8List()));

  final raw = BytesBuilder();
  for (int y = 0; y < h; y++) {
    raw.addByte(0);
    for (int x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      raw.addByte(rgba[i]);
      raw.addByte(rgba[i + 1]);
      raw.addByte(rgba[i + 2]);
      raw.addByte(rgba[i + 3]);
    }
  }
  final zlib = Uint8List.fromList(ZLibCodec(level: 9).encode(raw.toBytes()));
  out.add(_chunk('IDAT', zlib));
  out.add(_chunk('IEND', Uint8List(0)));
  return out.toBytes();
}

Uint8List _downscale(int target) {
  final out = Uint8List(target * target * 4);
  for (int y = 0; y < target; y++) {
    for (int x = 0; x < target; x++) {
      final sx = (x * _master / target).clamp(0, _master - 1).toInt();
      final sy = (y * _master / target).clamp(0, _master - 1).toInt();
      final i = (sy * _master + sx) * 4;
      final o = (y * target + x) * 4;
      out[o] = _px[i];
      out[o + 1] = _px[i + 1];
      out[o + 2] = _px[i + 2];
      out[o + 3] = _px[i + 3];
    }
  }
  return out;
}

void main() {
  _render();
  final dirs = <String, int>{
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  final base = 'android/app/src/main/res';
  for (final entry in dirs.entries) {
    final dir = '$base/${entry.key}';
    Directory(dir).createSync(recursive: true);
    final png = _pngEncode(_downscale(entry.value), entry.value, entry.value);
    File('$dir/ic_launcher.png').writeAsBytesSync(png);
    stdout.writeln('wrote $dir/ic_launcher.png (${entry.value}x${entry.value})');
  }
  // iOS app icons (from Assets.xcassets/AppIcon.appiconset).
  const iosIcons = <String, int>{
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  final iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  Directory(iosDir).createSync(recursive: true);
  for (final entry in iosIcons.entries) {
    final s = entry.value;
    final png = _pngEncode(_downscale(s), s, s);
    File('$iosDir/${entry.key}').writeAsBytesSync(png);
    stdout.writeln('wrote $iosDir/${entry.key} ($s)');
  }

  // Reference master icon.
  File('icon_master.png').writeAsBytesSync(_pngEncode(_px, _master, _master));
  stdout.writeln('wrote icon_master.png (1024x1024)');
}
