// ignore_for_file: require_trailing_commas

import 'dart:math';
import 'package:flutter/material.dart';

import '../../extended_image.dart';

class EditActionDetails {
  double _rotateRadian = 0.0;
  bool _flipX = false;
  bool _flipY = false;
  bool _computeHorizontalBoundary = false;
  bool _computeVerticalBoundary = false;
  Rect? _layoutRect;
  Rect? _screenDestinationRect;
  Rect? _rawDestinationRect;
  double _originalWidth = 0.0;
  double _originalHeight = 0.0;

  /// #235
  /// when we reach edge, we should not allow to zoom out.
  bool _reachCropRectEdge = false;
  bool isNeedBackToBounds = false;

  double totalScale = 1.0;
  double preTotalScale = 1.0;
  late Offset delta;
  Offset? screenFocalPoint;
  EdgeInsets? cropRectPadding;
  Rect? cropRect;

  /// aspect ratio of image
  double? originalAspectRatio;

  ///  aspect ratio of crop rect
  double? _cropAspectRatio;

  double? get cropAspectRatio {
    if (_cropAspectRatio != null) {
      return isHalfPi ? 1.0 / _cropAspectRatio! : _cropAspectRatio;
    }
    return null;
  }

  set cropAspectRatio(double? value) {
    _cropAspectRatio = value;
  }

  ///image
  Rect? get screenDestinationRect => _screenDestinationRect;

  void setScreenDestinationRect(Rect value) {
    _screenDestinationRect = value;
  }

  bool get flipX => _flipX;

  bool get flipY => _flipY;

  double get rotateRadian => _rotateRadian;

  bool get hasRotateAngle => !isTwoPi;

  bool get hasEditAction => hasRotateAngle || _flipX || _flipY;

  bool get needCrop => screenCropRect != screenDestinationRect;

  double get rotateAngle => (rotateRadian ~/ (pi / 2)) * 90.0;

  bool get needFlip => _flipX || _flipY;

  bool get isHalfPi => (_rotateRadian % pi) != 0;

  bool get isPi => !isHalfPi && !isTwoPi;

  bool get isTwoPi => (_rotateRadian % (2 * pi)) == 0;

  /// destination rect base on layer
  Rect? get layerDestinationRect =>
      screenDestinationRect?.shift(-layoutTopLeft!);

  Offset? get layoutTopLeft => _layoutRect?.topLeft;

  Rect? get rawDestinationRect => _rawDestinationRect;

  Rect? get screenCropRect => cropRect?.shift(layoutTopLeft!);

  bool get reachCropRectEdge => _reachCropRectEdge;

  void rotate(double angle, Rect layoutRect, BoxFit? fit) {
    if (cropRect == null) {
      return;
    }
    _rotateRadian += angle;
    _rotateRadian %= 2 * pi;
    if (_flipX && _flipY && isPi) {
      _flipX = _flipY = false;
      _rotateRadian = 0.0;
    }

    cropRect = rotateRect(cropRect!, cropRect!.center, -angle);
    // screenDestinationRect =
    //     rotateRect(screenDestinationRect, screenCropRect.center, -angle);

    /// take care of boundary
    final newCropRect = getDestinationRect(
      rect: layoutRect,
      inputSize: Size(cropRect!.height, cropRect!.width),
      fit: fit,
    );

    final scale = newCropRect.width / cropRect!.height;

    var newScreenDestinationRect =
        rotateRect(screenDestinationRect!, screenCropRect!.center, angle);

    final topLeft = screenCropRect!.center -
        (screenCropRect!.center - newScreenDestinationRect.topLeft) * scale;
    final bottomRight = screenCropRect!.center +
        -(screenCropRect!.center - newScreenDestinationRect.bottomRight) *
            scale;

    newScreenDestinationRect = Rect.fromPoints(topLeft, bottomRight);

    cropRect = newCropRect;
    _screenDestinationRect = newScreenDestinationRect;
    totalScale *= scale;
    preTotalScale = totalScale;
    if (totalScale < 1.0) {
      totalScale = 1.0;
    }
    if (preTotalScale < 1.0) {
      preTotalScale = 1.0;
    }
  }

  void flip() {
    if (screenCropRect == null) {
      return;
    }
    final flipOrigin = screenCropRect!.center;
    if (isHalfPi) {
      _flipX = !_flipX;
      // _screenDestinationRect = Rect.fromLTRB(
      //     screenDestinationRect.left,
      //     2 * flipOrigin.dy - screenDestinationRect.bottom,
      //     screenDestinationRect.right,
      //     2 * flipOrigin.dy - screenDestinationRect.top);
    } else {
      _flipY = !_flipY;
    }
    _screenDestinationRect = Rect.fromLTRB(
      2 * flipOrigin.dx - screenDestinationRect!.right,
      screenDestinationRect!.top,
      2 * flipOrigin.dx - screenDestinationRect!.left,
      screenDestinationRect!.bottom,
    );

    if (_flipX && _flipY && isPi) {
      _flipX = _flipY = false;
      _rotateRadian = 0.0;
    }
  }

  ///screen image rect to paint rect
  Rect paintRect(Rect rect) {
    if (!hasEditAction || screenCropRect == null) {
      return rect;
    }

    final flipOrigin = screenCropRect!.center;
    if (hasRotateAngle) {
      rect = rotateRect(rect, flipOrigin, -_rotateRadian);
    }

    if (flipY) {
      rect = Rect.fromLTRB(
        2 * flipOrigin.dx - rect.right,
        rect.top,
        2 * flipOrigin.dx - rect.left,
        rect.bottom,
      );
    }

    if (flipX) {
      rect = Rect.fromLTRB(
        rect.left,
        2 * flipOrigin.dy - rect.bottom,
        rect.right,
        2 * flipOrigin.dy - rect.top,
      );
    }

    return rect;
  }

  void initRect(Rect layoutRect, Rect destinationRect) {
    if (_layoutRect != layoutRect) {
      _layoutRect = layoutRect;
      _screenDestinationRect = null;
    }

    if (_rawDestinationRect != destinationRect) {
      _rawDestinationRect = destinationRect;
      _screenDestinationRect = null;
    }
  }

  Rect getFinalDestinationRect() {
    _reachCropRectEdge = false;

    if (screenDestinationRect != null) {
      /// scale
      if (totalScale < 1.0) {
        totalScale = 1.0;
      }
      if (preTotalScale < 1.0) {
        preTotalScale = 1.0;
      }
      final scaleDelta = totalScale / preTotalScale;
      if (scaleDelta != 1.0) {
        if (_originalWidth == 0.0) {
          _originalWidth = _screenDestinationRect!.width;
        }
        if (_originalHeight == 0.0) {
          _originalHeight = _screenDestinationRect!.height;
        }

        var focalPoint = screenFocalPoint ?? _screenDestinationRect!.center;
        focalPoint = Offset(
          focalPoint.dx
              .clamp(
                _screenDestinationRect!.left,
                _screenDestinationRect!.right,
              )
              .toDouble(),
          focalPoint.dy
              .clamp(
                _screenDestinationRect!.top,
                _screenDestinationRect!.bottom,
              )
              .toDouble(),
        );

        final width = _screenDestinationRect!.width * scaleDelta;
        final height = _screenDestinationRect!.height * scaleDelta;
        _screenDestinationRect = Rect.fromLTWH(
          focalPoint.dx -
              (focalPoint.dx - _screenDestinationRect!.left) * scaleDelta,
          focalPoint.dy -
              (focalPoint.dy - _screenDestinationRect!.top) * scaleDelta,
          (width < _originalWidth) ? _originalWidth : width,
          (height < _originalHeight) ? _originalHeight : height,
        );
        preTotalScale = totalScale;
        if (totalScale < 1.0) {
          totalScale = 1.0;
        }
        if (preTotalScale < 1.0) {
          preTotalScale = 1.0;
        }
        delta = Offset.zero;
      }

      /// move
      else {
        if (_screenDestinationRect != screenCropRect) {
          _screenDestinationRect = _screenDestinationRect!.shift(delta);
        }
        //we have shift offset, we should clear delta.
        delta = Offset.zero;
      }

      final boundaryRect =
          computeBoundary(_screenDestinationRect!, screenCropRect!);
      if (isNeedBackToBounds) {
        _screenDestinationRect = boundaryRect;
        isNeedBackToBounds = false;
      }

      // make sure that crop rect is all in image rect.
      if (screenCropRect != null) {
        var rect = screenCropRect!.expandToInclude(_screenDestinationRect!);
        if (rect != _screenDestinationRect) {
          final topSame = doubleEqual(rect.top, screenCropRect!.top);
          final leftSame = doubleEqual(rect.left, screenCropRect!.left);
          final bottomSame = doubleEqual(rect.bottom, screenCropRect!.bottom);
          final rightSame = doubleEqual(rect.right, screenCropRect!.right);

          // make sure that image rect keep same aspect ratio
          if (topSame && bottomSame) {
            _reachCropRectEdge = true;
          } else if (leftSame && rightSame) {
            _reachCropRectEdge = true;
          }
        }
      }
    } else {
      _screenDestinationRect = getRectWithScale(_rawDestinationRect!);
    }

    return _screenDestinationRect!;
  }

  Rect getRectWithScale(Rect rect) {
    final width = rect.width * totalScale;
    final height = rect.height * totalScale;
    final center = rect.center;
    return Rect.fromLTWH(
      center.dx - width / 2.0,
      center.dy - height / 2.0,
      width,
      height,
    );
  }

  Rect computeBoundary(Rect result, Rect layoutRect) {
    if (_computeHorizontalBoundary) {
      //move right
      if (doubleCompare(result.left, layoutRect.left) >= 0) {
        result = Rect.fromLTWH(
          layoutRect.left,
          result.top,
          result.width,
          result.height,
        );
      }

      ///move left
      if (doubleCompare(result.right, layoutRect.right) <= 0) {
        result = Rect.fromLTWH(
          layoutRect.right - result.width,
          result.top,
          result.width,
          result.height,
        );
      }
    }

    if (_computeVerticalBoundary) {
      //move down
      if (doubleCompare(result.bottom, layoutRect.bottom) <= 0) {
        result = Rect.fromLTWH(
          result.left,
          layoutRect.bottom - result.height,
          result.width,
          result.height,
        );
      }

      //move up
      if (doubleCompare(result.top, layoutRect.top) >= 0) {
        result = Rect.fromLTWH(
          result.left,
          layoutRect.top,
          result.width,
          result.height,
        );
      }
    }

    _computeHorizontalBoundary = true;
    _computeVerticalBoundary = true;
    return result;
  }
}

class EditorConfig {
  EditorConfig({
    this.maxScale = 5.0,
    this.cropRectPadding = const EdgeInsets.all(20.0),
    this.cornerSize = const Size(30.0, 5.0),
    this.cornerColor,
    this.lineColor,
    this.lineHeight = 0.6,
    this.editorMaskColorHandler,
    this.hitTestSize = 20.0,
    this.animationDuration = const Duration(milliseconds: 200),
    this.tickerDuration = const Duration(milliseconds: 400),
    this.cropAspectRatio = CropAspectRatios.custom,
    this.initCropRectType = InitCropRectType.imageRect,
    this.cropLayerPainter = const EditorCropLayerPainter(),
    this.speed = 1.0,
    this.hitTestBehavior = HitTestBehavior.deferToChild,
    this.editActionDetailsIsChanged,
  })  : assert(lineHeight > 0.0),
        assert(hitTestSize > 0.0),
        assert(maxScale > 0.0),
        assert(speed > 0.0);

  /// Call when EditActionDetails is changed
  final EditActionDetailsIsChanged? editActionDetailsIsChanged;

  /// How to behave during hit tests.
  final HitTestBehavior hitTestBehavior;

  /// Max scale
  final double maxScale;

  /// Padding of crop rect to layout rect
  /// it's refer to initial image rect and crop rect
  final EdgeInsets cropRectPadding;

  /// Size of corner shape
  final Size cornerSize;

  /// Color of corner shape
  /// default: primaryColor
  final Color? cornerColor;

  /// Color of crop line
  /// default: scaffoldBackgroundColor.withOpacity(0.7)
  final Color? lineColor;

  /// Height of crop line
  final double lineHeight;

  /// Editor mask color base on pointerDown
  /// default: scaffoldBackgroundColor.withOpacity(pointerDown ? 0.4 : 0.8)
  final EditorMaskColorHandler? editorMaskColorHandler;

  /// Hit test region of corner and line
  final double hitTestSize;

  /// Auto center animation duration
  final Duration animationDuration;

  /// Duration to begin auto center animation after crop rect is changed
  final Duration tickerDuration;

  /// Aspect ratio of crop rect
  /// default is custom
  final double? cropAspectRatio;

  /// Init crop rect base on initial image rect or image layout rect
  final InitCropRectType initCropRectType;

  /// Custom crop layer
  final EditorCropLayerPainter cropLayerPainter;

  /// Speed for zoom/pan
  final double speed;
}

class CropAspectRatios {
  /// no aspect ratio for crop
  static const double? custom = null;

  /// the same as aspect ratio of image
  /// [cropAspectRatio] is not more than 0.0, it's original
  static const double original = 0.0;

  /// ratio of width and height is 1 : 1
  static const double ratio1_1 = 1.0;

  /// ratio of width and height is 3 : 4
  static const double ratio3_4 = 3.0 / 4.0;

  /// ratio of width and height is 4 : 3
  static const double ratio4_3 = 4.0 / 3.0;

  /// ratio of width and height is 9 : 16
  static const double ratio9_16 = 9.0 / 16.0;

  /// ratio of width and height is 16 : 9
  static const double ratio16_9 = 16.0 / 9.0;
}

Rect getDestinationRect({
  required Rect rect,
  required Size inputSize,
  double scale = 1.0,
  BoxFit? fit,
  Alignment alignment = Alignment.center,
  Rect? centerSlice,
  bool flipHorizontally = false,
}) {
  var outputSize = rect.size;

  late Offset sliceBorder;
  if (centerSlice != null) {
    sliceBorder = Offset(
      centerSlice.left + inputSize.width - centerSlice.right,
      centerSlice.top + inputSize.height - centerSlice.bottom,
    );
    outputSize = outputSize - sliceBorder as Size;
    inputSize = inputSize - sliceBorder as Size;
  }
  fit ??= centerSlice == null ? BoxFit.scaleDown : BoxFit.fill;
  assert(centerSlice == null || (fit != BoxFit.none && fit != BoxFit.cover));
  final fittedSizes = applyBoxFit(fit, inputSize / scale, outputSize);
  final sourceSize = fittedSizes.source * scale;
  var destinationSize = fittedSizes.destination;
  if (centerSlice != null) {
    outputSize += sliceBorder;
    destinationSize += sliceBorder;
    // We don't have the ability to draw a subset of the image at the same time
    // as we apply a nine-patch stretch.
    assert(sourceSize == inputSize,
        'centerSlice was used with a BoxFit that does not guarantee that the image is fully visible.');
  }

  final halfWidthDelta = (outputSize.width - destinationSize.width) / 2.0;
  final halfHeightDelta = (outputSize.height - destinationSize.height) / 2.0;
  final dx = halfWidthDelta +
      (flipHorizontally ? -alignment.x : alignment.x) * halfWidthDelta;
  final dy = halfHeightDelta + alignment.y * halfHeightDelta;
  final destinationPosition = rect.topLeft.translate(dx, dy);
  final destinationRect = destinationPosition & destinationSize;

  // final Rect sourceRect =
  //     centerSlice ?? alignment.inscribe(sourceSize, Offset.zero & inputSize);

  return destinationRect;
}

Color defaultEditorMaskColorHandler(BuildContext context, bool pointerDown) {
  return Theme.of(context)
      .scaffoldBackgroundColor
      .withOpacity(pointerDown ? 0.4 : 0.8);
}

Offset rotateOffset(Offset input, Offset center, double angle) {
  final x = input.dx;
  final y = input.dy;
  final rx0 = center.dx;
  final ry0 = center.dy;
  final x0 = (x - rx0) * cos(angle) - (y - ry0) * sin(angle) + rx0;
  final y0 = (x - rx0) * sin(angle) + (y - ry0) * cos(angle) + ry0;
  return Offset(x0, y0);
}

Rect rotateRect(Rect rect, Offset center, double angle) {
  final leftTop = rotateOffset(rect.topLeft, center, angle);
  final bottomRight = rotateOffset(rect.bottomRight, center, angle);
  return Rect.fromPoints(leftTop, bottomRight);
}

enum InitCropRectType {
  //init crop rect base on initial image rect
  imageRect,
  //init crop rect base on image layout rect
  layoutRect
}

class EditorCropLayerPainter {
  const EditorCropLayerPainter();

  void paint(Canvas canvas, Size size, ExtendedImageCropLayerPainter painter) {
    paintCircle(canvas, size, painter);
  }

  /// draw crop layer circle
  void paintCircle(
      Canvas canvas, Size size, ExtendedImageCropLayerPainter painter) {
    canvas.drawCircle(
      painter.cropRect.center,
      max((painter.cropRect.height / 2), (painter.cropRect.width / 2)),
      Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }
}

class ExtendedImageCropLayerPainter extends CustomPainter {
  ExtendedImageCropLayerPainter({
    required this.cropRect,
    required this.cropLayerPainter,
    required this.lineColor,
    required this.cornerColor,
    required this.cornerSize,
    required this.lineHeight,
    required this.maskColor,
    required this.pointerDown,
  });

  /// The rect of crop layer
  final Rect cropRect;

  /// The size of corner shape
  final Size cornerSize;

  // The color of corner shape
  // default theme primaryColor
  final Color cornerColor;

  /// The color of crop line
  final Color lineColor;

  /// The height of crop line
  final double lineHeight;

  /// The color of mask
  final Color maskColor;

  /// Whether pointer is down
  final bool pointerDown;

  /// The crop Layer painter for Editor
  final EditorCropLayerPainter cropLayerPainter;

  @override
  void paint(Canvas canvas, Size size) {
    cropLayerPainter.paint(canvas, size, this);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate.runtimeType != runtimeType) {
      return true;
    }
    final delegate = oldDelegate as ExtendedImageCropLayerPainter;
    return cropRect != delegate.cropRect ||
        cornerSize != delegate.cornerSize ||
        lineColor != delegate.lineColor ||
        lineHeight != delegate.lineHeight ||
        maskColor != delegate.maskColor ||
        cropLayerPainter != delegate.cropLayerPainter ||
        cornerColor != delegate.cornerColor ||
        pointerDown != delegate.pointerDown;
  }
}
