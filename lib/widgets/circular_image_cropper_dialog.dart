// lib/widgets/circular_image_cropper_dialog.dart

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A pure Flutter, cross-platform circular image cropper dialog that works seamlessly
/// on Web, Android, iOS, and Desktop without any external native or JS dependencies.
class CircularImageCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;
  final double outputSize;

  const CircularImageCropperDialog({
    super.key,
    required this.imageBytes,
    this.title = 'Crop Profile Photo',
    this.outputSize = 600.0,
  });

  /// Opens the circular image cropper modal and returns cropped PNG bytes or null if canceled.
  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    String title = 'Crop Profile Photo',
    double outputSize = 600.0,
  }) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CircularImageCropperDialog(
        imageBytes: imageBytes,
        title: title,
        outputSize: outputSize,
      ),
    );
  }

  @override
  State<CircularImageCropperDialog> createState() =>
      _CircularImageCropperDialogState();
}

class _CircularImageCropperDialogState
    extends State<CircularImageCropperDialog> {
  ui.Image? _uiImage;
  bool _isLoading = true;
  bool _isCropping = false;
  String? _errorMessage;

  final TransformationController _transformController =
      TransformationController();

  Size _viewportSize = Size.zero;
  double _circleRadius = 130.0;
  double _currentScale = 1.0;
  double _minScale = 0.5;
  double _maxScale = 4.0;
  bool _initializedTransform = false;

  @override
  void initState() {
    super.initState();
    _loadImage(widget.imageBytes);
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _uiImage?.dispose();
    super.dispose();
  }

  Future<void> _loadImage(Uint8List bytes) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final loadedImage = frame.image;

      if (!mounted) {
        loadedImage.dispose();
        return;
      }

      setState(() {
        _uiImage?.dispose();
        _uiImage = loadedImage;
        _isLoading = false;
        _initializedTransform = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load image: $e';
        });
      }
    }
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _initTransformIfReady() {
    if (_uiImage == null || _viewportSize == Size.zero || _initializedTransform) {
      return;
    }

    final imgW = _uiImage!.width.toDouble();
    final imgH = _uiImage!.height.toDouble();
    final vpW = _viewportSize.width;
    final vpH = _viewportSize.height;

    // Determine circular crop diameter
    final diameter = math.min(vpW * 0.86, vpH * 0.75).clamp(240.0, 360.0);
    _circleRadius = diameter / 2.0;

    // Minimum scale required to completely cover the circular crop area
    final minCoverScale = math.max(diameter / imgW, diameter / imgH);
    _minScale = minCoverScale * 0.8;
    _maxScale = minCoverScale * 4.0;
    _currentScale = minCoverScale;

    // Center image over the circle center (vpW / 2, vpH / 2)
    final tx = (vpW - imgW * minCoverScale) / 2.0;
    final ty = (vpH - imgH * minCoverScale) / 2.0;

    _transformController.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(minCoverScale);

    _initializedTransform = true;
  }

  void _updateZoom(double newScale) {
    if (_uiImage == null || _viewportSize == Size.zero) return;

    final currentMatrix = _transformController.value;
    try {
      final inverse = Matrix4.inverted(currentMatrix);
      final centerInChild = MatrixUtils.transformPoint(
        inverse,
        Offset(_viewportSize.width / 2, _viewportSize.height / 2),
      );

      final newMatrix = Matrix4.identity()
        ..translate(_viewportSize.width / 2, _viewportSize.height / 2)
        ..scale(newScale)
        ..translate(-centerInChild.dx, -centerInChild.dy);

      _transformController.value = newMatrix;
      setState(() => _currentScale = newScale);
    } catch (_) {
      // Fallback
      _transformController.value = Matrix4.identity()
        ..translate(
          (_viewportSize.width - _uiImage!.width * newScale) / 2,
          (_viewportSize.height - _uiImage!.height * newScale) / 2,
        )
        ..scale(newScale);
      setState(() => _currentScale = newScale);
    }
  }

  Future<void> _rotateClockwise() async {
    if (_uiImage == null) return;

    try {
      setState(() => _isLoading = true);

      final orig = _uiImage!;
      final newW = orig.height;
      final newH = orig.width;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, newW.toDouble(), newH.toDouble()),
      );

      canvas.translate(newW / 2.0, newH / 2.0);
      canvas.rotate(math.pi / 2.0);
      canvas.drawImage(
        orig,
        Offset(-orig.width / 2.0, -orig.height / 2.0),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final rotated = await picture.toImage(newW, newH);

      if (!mounted) {
        rotated.dispose();
        return;
      }

      setState(() {
        _uiImage?.dispose();
        _uiImage = rotated;
        _isLoading = false;
        _initializedTransform = false;
      });

      // Reinitialize transform with the newly oriented image
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _initTransformIfReady();
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rotate: $e')),
        );
      }
    }
  }

  void _resetTransform() {
    _initializedTransform = false;
    setState(() {
      _initTransformIfReady();
    });
  }

  Future<void> _cropAndConfirm() async {
    if (_uiImage == null || _viewportSize == Size.zero) return;

    setState(() => _isCropping = true);

    try {
      final outSize = widget.outputSize;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outSize, outSize));

      // Clip strictly to a circle
      final circlePath = Path()
        ..addOval(Rect.fromLTWH(0, 0, outSize, outSize));
      canvas.clipPath(circlePath);

      canvas.save();
      // Map viewport circle space to output canvas space
      canvas.translate(outSize / 2.0, outSize / 2.0);
      canvas.scale(outSize / (2.0 * _circleRadius));
      canvas.translate(-_viewportSize.width / 2.0, -_viewportSize.height / 2.0);

      // Apply the user's interactive translation and zoom
      canvas.transform(_transformController.value.storage);

      // Draw the full-resolution source image
      canvas.drawImageRect(
        _uiImage!,
        Rect.fromLTWH(
          0,
          0,
          _uiImage!.width.toDouble(),
          _uiImage!.height.toDouble(),
        ),
        Rect.fromLTWH(
          0,
          0,
          _uiImage!.width.toDouble(),
          _uiImage!.height.toDouble(),
        ),
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high,
      );
      canvas.restore();

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(
        outSize.toInt(),
        outSize.toInt(),
      );

      final byteData =
          await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      croppedImage.dispose();

      if (byteData == null) {
        throw Exception('Could not extract byte data from cropped image');
      }

      final croppedBytes = byteData.buffer.asUint8List();

      if (mounted) {
        Navigator.of(context).pop(croppedBytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cropping image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0F172A), // Dark slate studio backdrop
      child: SafeArea(
        child: Column(
          children: [
            // Top App Bar Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Cancel',
                    onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Pinch or drag to fit in the circle',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.restart_alt_rounded, color: Colors.white70),
                    tooltip: 'Reset view',
                    onPressed: _isCropping ? null : _resetTransform,
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: (_isLoading || _isCropping || _uiImage == null)
                        ? null
                        : _cropAndConfirm,
                    icon: _isCropping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(_isCropping ? 'Cropping...' : 'Crop & Use'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981), // Emerald
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Interactive Crop Viewport
            Expanded(
              child: Container(
                color: const Color(0xFF020617), // Deep dark workspace
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    if (_viewportSize != size) {
                      _viewportSize = size;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _initTransformIfReady();
                          });
                        }
                      });
                    }

                    if (_isLoading) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF10B981)),
                            SizedBox(height: 16),
                            Text(
                              'Loading image...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    }

                    if (_errorMessage != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Colors.redAccent, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (_uiImage == null) {
                      return const SizedBox.shrink();
                    }

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Interactive Image Canvas
                        InteractiveViewer(
                          transformationController: _transformController,
                          minScale: _minScale,
                          maxScale: _maxScale,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          panEnabled: !_isCropping,
                          scaleEnabled: !_isCropping,
                          child: SizedBox(
                            width: _uiImage!.width.toDouble(),
                            height: _uiImage!.height.toDouble(),
                            child: RawImage(
                              image: _uiImage,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),

                        // Mask Overlay with Circular Cutout & Grid
                        IgnorePointer(
                          child: CustomPaint(
                            size: size,
                            painter: _CircleCropOverlayPainter(
                              circleRadius: _circleRadius,
                              center: Offset(size.width / 2, size.height / 2),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Bottom Controls Bar (Zoom Slider, Buttons, Rotate)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom Slider Row
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.zoom_out_rounded, color: Colors.white70),
                        tooltip: 'Zoom Out',
                        onPressed: (_isLoading || _isCropping || _uiImage == null)
                            ? null
                            : () => _updateZoom(
                                  math.max(_minScale, _currentScale - 0.2),
                                ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF10B981),
                            inactiveTrackColor: Colors.white.withOpacity(0.15),
                            thumbColor: const Color(0xFF10B981),
                            overlayColor: const Color(0xFF10B981).withOpacity(0.2),
                            trackHeight: 3.5,
                          ),
                          child: Slider(
                            value: _currentScale.clamp(_minScale, _maxScale),
                            min: _minScale,
                            max: _maxScale,
                            onChanged: (_isLoading || _isCropping || _uiImage == null)
                                ? null
                                : (val) => _updateZoom(val),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.zoom_in_rounded, color: Colors.white70),
                        tooltip: 'Zoom In',
                        onPressed: (_isLoading || _isCropping || _uiImage == null)
                            ? null
                            : () => _updateZoom(
                                  math.min(_maxScale, _currentScale + 0.2),
                                ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Action Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: (_isLoading || _isCropping || _uiImage == null)
                            ? null
                            : _rotateClockwise,
                        icon: const Icon(Icons.rotate_90_degrees_cw_rounded,
                            color: Colors.white70, size: 20),
                        label: const Text(
                          'Rotate 90°',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          backgroundColor: Colors.white.withOpacity(0.06),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: (_isLoading || _isCropping || _uiImage == null)
                            ? null
                            : _resetTransform,
                        icon: const Icon(Icons.center_focus_strong_rounded,
                            color: Colors.white70, size: 20),
                        label: const Text(
                          'Center Photo',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          backgroundColor: Colors.white.withOpacity(0.06),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that creates the dark scrim with a circular transparent hole
/// and rule-of-thirds alignment guide lines.
class _CircleCropOverlayPainter extends CustomPainter {
  final double circleRadius;
  final Offset center;

  _CircleCropOverlayPainter({
    required this.circleRadius,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()
      ..color = Colors.black.withOpacity(0.68)
      ..style = PaintingStyle.fill;

    // Full screen rect
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fullPath = Path()..addRect(fullRect);

    // Circular hole path
    final circleRect = Rect.fromCircle(center: center, radius: circleRadius);
    final circlePath = Path()..addOval(circleRect);

    // Scrim with hole
    final overlayPath = Path.combine(
      PathOperation.difference,
      fullPath,
      circlePath,
    );
    canvas.drawPath(overlayPath, scrimPaint);

    // Circular boundary line with subtle glowing border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..isAntiAlias = true;
    canvas.drawCircle(center, circleRadius, borderPaint);

    // Subtle emerald outer indicator
    final outerRingPaint = Paint()
      ..color = const Color(0xFF10B981).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, circleRadius + 3.0, outerRingPaint);

    // Rule-of-thirds guidelines inside circle
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.save();
    canvas.clipPath(circlePath);

    final left = circleRect.left;
    final top = circleRect.top;
    final d = circleRadius * 2.0;

    // Vertical third lines
    canvas.drawLine(
      Offset(left + d / 3.0, top),
      Offset(left + d / 3.0, top + d),
      gridPaint,
    );
    canvas.drawLine(
      Offset(left + (2.0 * d) / 3.0, top),
      Offset(left + (2.0 * d) / 3.0, top + d),
      gridPaint,
    );

    // Horizontal third lines
    canvas.drawLine(
      Offset(left, top + d / 3.0),
      Offset(left + d, top + d / 3.0),
      gridPaint,
    );
    canvas.drawLine(
      Offset(left, top + (2.0 * d) / 3.0),
      Offset(left + d, top + (2.0 * d) / 3.0),
      gridPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CircleCropOverlayPainter oldDelegate) {
    return oldDelegate.circleRadius != circleRadius ||
        oldDelegate.center != center;
  }
}
