import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Raw face measurements handed to the cartoonizer (all in source-image pixels).
/// Plain values only so it can cross an isolate boundary.
class FaceBox {
  final double left;
  final double top;
  final double width;
  final double height;
  final List<double>? leftEye; // [x, y]
  final List<double>? rightEye; // [x, y]
  final double? smiling;
  final double? eyesOpen;
  final double headTilt;

  const FaceBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.leftEye,
    this.rightEye,
    this.smiling,
    this.eyesOpen,
    this.headTilt = 0,
  });
}

class CartoonRequest {
  final Uint8List imageBytes;
  final FaceBox? face;
  const CartoonRequest(this.imageBytes, this.face);
}

/// Output of the cartoon pass: a transparent round PNG portrait plus the
/// measurements the villain generator needs.
class CartoonResult {
  final Uint8List png;

  /// Un-stylised, tightly cropped face photo (JPEG) used to texture the 3D
  /// head so the villain looks like the real person.
  final Uint8List photoJpg;
  final int skinTone; // ARGB
  final int hairColor; // ARGB
  final int shirtColor; // ARGB
  final double brightness;
  final double contrast;
  final double faceAspect;
  final double? smiling;
  final double? eyesOpen;
  final double headTilt;
  final bool faceDetected;
  final int seed;
  final List<double> leftEye; // relative 0..1
  final List<double> rightEye; // relative 0..1

  const CartoonResult({
    required this.png,
    required this.photoJpg,
    required this.skinTone,
    required this.hairColor,
    required this.shirtColor,
    required this.brightness,
    required this.contrast,
    required this.faceAspect,
    required this.smiling,
    required this.eyesOpen,
    required this.headTilt,
    required this.faceDetected,
    required this.seed,
    required this.leftEye,
    required this.rightEye,
  });
}

const int portraitSize = 256;

/// Turns a photo into a cel-shaded, ink-outlined, round cartoon portrait.
/// Pure Dart so it can run inside `compute()`.
CartoonResult cartoonizeFace(CartoonRequest request) {
  final decoded = img.decodeImage(request.imageBytes);
  if (decoded == null) {
    throw const FormatException('Could not read that image.');
  }
  final src = img.bakeOrientation(decoded);
  final face = request.face;

  // 1. Square crop around the face (with room for hair and chin).
  double cx, cy, side;
  if (face != null) {
    cx = face.left + face.width / 2;
    cy = face.top + face.height / 2 - face.height * 0.1;
    side = math.max(face.width, face.height) * 1.4;
  } else {
    cx = src.width / 2;
    cy = src.height * 0.45;
    side = math.min(src.width, src.height) * 0.85;
  }
  side = math.min(side, math.min(src.width, src.height).toDouble());
  var x0 = (cx - side / 2).clamp(0, src.width - side).toDouble();
  var y0 = (cy - side / 2).clamp(0, src.height - side).toDouble();

  final cropped = img.copyCrop(
    src,
    x: x0.round(),
    y: y0.round(),
    width: side.round(),
    height: side.round(),
  );
  final scale = portraitSize / side;
  var base = img.copyResize(
    cropped,
    width: portraitSize,
    height: portraitSize,
    interpolation: img.Interpolation.average,
  );
  base = base.convert(numChannels: 4);

  // Tight, un-stylised face crop for the 3D head texture.
  final img.Image photo;
  if (face != null) {
    final pSide = math.min(math.max(face.width, face.height) * 1.18,
        math.min(src.width, src.height).toDouble());
    final px = (face.left + face.width / 2 - pSide / 2).clamp(0, src.width - pSide).toDouble();
    final py = (face.top + face.height / 2 - face.height * 0.06 - pSide / 2)
        .clamp(0, src.height - pSide)
        .toDouble();
    photo = img.copyResize(
      img.copyCrop(src, x: px.round(), y: py.round(), width: pSide.round(), height: pSide.round()),
      width: portraitSize,
      height: portraitSize,
      interpolation: img.Interpolation.average,
    );
  } else {
    photo = img.copyResize(img.copyCrop(base, x: 26, y: 20, width: 204, height: 204),
        width: portraitSize, height: portraitSize);
  }

  // Face rectangle inside the portrait.
  double fl, ft, fw, fh;
  if (face != null) {
    fl = (face.left - x0) * scale;
    ft = (face.top - y0) * scale;
    fw = face.width * scale;
    fh = face.height * scale;
  } else {
    fw = portraitSize * 0.58;
    fh = portraitSize * 0.68;
    fl = (portraitSize - fw) / 2;
    ft = portraitSize * 0.2;
  }

  List<double> eyeRel(List<double>? p, double defX) {
    if (p != null) {
      return [
        (((p[0] - x0) * scale) / portraitSize).clamp(0.0, 1.0),
        (((p[1] - y0) * scale) / portraitSize).clamp(0.0, 1.0),
      ];
    }
    return [
      ((fl + fw * defX) / portraitSize).clamp(0.0, 1.0),
      ((ft + fh * 0.4) / portraitSize).clamp(0.0, 1.0),
    ];
  }

  // Note: the photo's "left eye" is on the right of the image.
  final eyeA = eyeRel(face?.leftEye, 0.68);
  final eyeB = eyeRel(face?.rightEye, 0.32);
  final leftEye = eyeA[0] < eyeB[0] ? eyeA : eyeB;
  final rightEye = eyeA[0] < eyeB[0] ? eyeB : eyeA;

  // 2. Measure colours.
  final skin = _averageColor(base, fl + fw * 0.3, ft + fh * 0.5, fw * 0.4,
      fh * 0.25, rejectExtremes: true);
  final hair = _averageColor(base, fl + fw * 0.2, ft - fh * 0.12, fw * 0.6,
      fh * 0.14, rejectExtremes: false);
  final shirt = _averageColor(base, portraitSize * 0.25, portraitSize * 0.9,
      portraitSize * 0.5, portraitSize * 0.09, rejectExtremes: false);

  double lumSum = 0, lumSq = 0;
  int lumCount = 0;
  int seed = 17;
  for (int y = ft.toInt().clamp(0, portraitSize - 1);
      y < (ft + fh).toInt().clamp(0, portraitSize);
      y += 2) {
    for (int x = fl.toInt().clamp(0, portraitSize - 1);
        x < (fl + fw).toInt().clamp(0, portraitSize);
        x += 2) {
      final p = base.getPixel(x, y);
      final l = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;
      lumSum += l;
      lumSq += l * l;
      lumCount++;
      seed = (seed * 31 + (l * 255).toInt()) & 0x7fffffff;
    }
  }
  final mean = lumCount > 0 ? lumSum / lumCount : 0.5;
  final variance = lumCount > 0 ? (lumSq / lumCount) - mean * mean : 0.0;
  final contrast = (math.sqrt(math.max(0, variance)) / 0.3).clamp(0.0, 1.0);

  // 3. Cel shading: smooth, then posterize while keeping hue.
  final smooth = img.gaussianBlur(base.clone(), radius: 2);
  final toon = img.Image(width: portraitSize, height: portraitSize, numChannels: 4);
  const levels = 5;
  for (int y = 0; y < portraitSize; y++) {
    for (int x = 0; x < portraitSize; x++) {
      final p = smooth.getPixel(x, y);
      final r = p.r / 255.0, g = p.g / 255.0, b = p.b / 255.0;
      final mx = math.max(r, math.max(g, b));
      final mn = math.min(r, math.min(g, b));
      // Quantise brightness into bands, boost saturation a little.
      final v = mx;
      final qv = ((v * (levels - 1)).round() / (levels - 1)).clamp(0.08, 1.0);
      final sat = mx > 0 ? (mx - mn) / mx : 0.0;
      final newSat = (sat * 1.3).clamp(0.0, 1.0);
      double scaleC(double c) {
        if (mx == 0) return qv;
        final relative = mx - mn == 0 ? 1.0 : (c - mn) / (mx - mn);
        final cc = qv * (1 - newSat) + qv * newSat * relative;
        return cc;
      }

      // Slight villainous grade: cool, purple-ish shadows.
      var nr = scaleC(r), ng = scaleC(g), nb = scaleC(b);
      final shadow = 1 - qv;
      nr = nr * (1 - shadow * 0.15) + shadow * 0.06;
      ng = ng * (1 - shadow * 0.3);
      nb = nb * (1 - shadow * 0.05) + shadow * 0.12;
      toon.setPixelRgba(
        x,
        y,
        (nr * 255).clamp(0, 255),
        (ng * 255).clamp(0, 255),
        (nb * 255).clamp(0, 255),
        255,
      );
    }
  }

  // 4. Ink outlines from luminance edges (adaptive threshold).
  final lum = List<double>.filled(portraitSize * portraitSize, 0);
  final edgeSrc = img.gaussianBlur(base.clone(), radius: 1);
  for (int y = 0; y < portraitSize; y++) {
    for (int x = 0; x < portraitSize; x++) {
      final p = edgeSrc.getPixel(x, y);
      lum[y * portraitSize + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    }
  }
  final mags = List<double>.filled(portraitSize * portraitSize, 0);
  for (int y = 1; y < portraitSize - 1; y++) {
    for (int x = 1; x < portraitSize - 1; x++) {
      double at(int dx, int dy) => lum[(y + dy) * portraitSize + (x + dx)];
      final gx = -at(-1, -1) - 2 * at(-1, 0) - at(-1, 1) +
          at(1, -1) + 2 * at(1, 0) + at(1, 1);
      final gy = -at(-1, -1) - 2 * at(0, -1) - at(1, -1) +
          at(-1, 1) + 2 * at(0, 1) + at(1, 1);
      mags[y * portraitSize + x] = math.sqrt(gx * gx + gy * gy);
    }
  }
  final sorted = List<double>.from(mags)..sort();
  final threshold = math.max(60.0, sorted[(sorted.length * 0.86).toInt()]);
  for (int i = 0; i < mags.length; i++) {
    final m = mags[i];
    if (m <= threshold) continue;
    final strength = ((m - threshold) / threshold).clamp(0.35, 1.0);
    final x = i % portraitSize, y = i ~/ portraitSize;
    final p = toon.getPixel(x, y);
    toon.setPixelRgba(
      x,
      y,
      p.r * (1 - strength) + 26 * strength,
      p.g * (1 - strength) + 14 * strength,
      p.b * (1 - strength) + 34 * strength,
      255,
    );
  }

  // 5. Round mask with a thick ink rim.
  const c = portraitSize / 2;
  const radius = portraitSize / 2 - 2;
  for (int y = 0; y < portraitSize; y++) {
    for (int x = 0; x < portraitSize; x++) {
      final d = math.sqrt((x + 0.5 - c) * (x + 0.5 - c) + (y + 0.5 - c) * (y + 0.5 - c));
      if (d > radius) {
        final a = (1 - (d - radius)).clamp(0.0, 1.0);
        final p = toon.getPixel(x, y);
        toon.setPixelRgba(x, y, 26, 14, 34, (a * 255).round());
        if (a == 0) toon.setPixelRgba(x, y, p.r, p.g, p.b, 0);
      } else if (d > radius - 6) {
        toon.setPixelRgba(x, y, 26, 14, 34, 255);
      }
    }
  }

  return CartoonResult(
    png: Uint8List.fromList(img.encodePng(toon)),
    photoJpg: Uint8List.fromList(img.encodeJpg(photo, quality: 88)),
    skinTone: skin,
    hairColor: hair,
    shirtColor: shirt,
    brightness: mean.clamp(0.0, 1.0),
    contrast: contrast,
    faceAspect: fh > 0 ? (fw / fh).clamp(0.5, 1.5) : 0.8,
    smiling: face?.smiling,
    eyesOpen: face?.eyesOpen,
    headTilt: face?.headTilt ?? 0,
    faceDetected: face != null,
    seed: seed,
    leftEye: leftEye,
    rightEye: rightEye,
  );
}

int _averageColor(img.Image image, double left, double top, double width,
    double height,
    {required bool rejectExtremes}) {
  final x0 = left.floor().clamp(0, image.width - 1);
  final y0 = top.floor().clamp(0, image.height - 1);
  final x1 = (left + width).ceil().clamp(x0 + 1, image.width);
  final y1 = (top + height).ceil().clamp(y0 + 1, image.height);
  double r = 0, g = 0, b = 0;
  int n = 0;
  for (int y = y0; y < y1; y++) {
    for (int x = x0; x < x1; x++) {
      final p = image.getPixel(x, y);
      if (rejectExtremes) {
        final l = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        if (l < 40 || l > 235) continue;
      }
      r += p.r;
      g += p.g;
      b += p.b;
      n++;
    }
  }
  if (n == 0) return 0xFFC68642;
  return 0xFF000000 |
      ((r / n).round() << 16) |
      ((g / n).round() << 8) |
      (b / n).round();
}
