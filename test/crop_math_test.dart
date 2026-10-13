import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Canvas crop transformation math correctly maps viewport to output canvas', () async {
    const double viewportWidth = 400.0;
    const double viewportHeight = 600.0;
    const double circleRadius = 150.0;
    const double outputSize = 512.0;

    const double childWidth = 300.0;
    const double childHeight = 300.0;

    // Suppose user centered the child:
    final matrix = Matrix4.identity()
      ..translate((viewportWidth - childWidth) / 2, (viewportHeight - childHeight) / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, outputSize, outputSize));

    final circlePath = Path()
      ..addOval(const Rect.fromLTWH(0, 0, outputSize, outputSize));
    canvas.clipPath(circlePath);

    canvas.save();
    canvas.translate(outputSize / 2, outputSize / 2);
    canvas.scale(outputSize / (2 * circleRadius));
    canvas.translate(-viewportWidth / 2, -viewportHeight / 2);
    canvas.transform(matrix.storage);

    // Draw a rect of child size
    final paint = Paint()..color = Colors.blue;
    canvas.drawRect(const Rect.fromLTWH(0, 0, childWidth, childHeight), paint);
    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(outputSize.toInt(), outputSize.toInt());
    expect(img.width, 512);
    expect(img.height, 512);

    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    expect(byteData, isNotNull);
    expect(byteData!.lengthInBytes, greaterThan(0));
  });

  test('rotateUiImage correctly rotates an image 90 degrees', () async {
    // Create a 100x200 image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 100, 200));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 200), Paint()..color = Colors.red);
    final picture = recorder.endRecording();
    final original = await picture.toImage(100, 200);

    expect(original.width, 100);
    expect(original.height, 200);

    // Rotate 90 degrees clockwise:
    final rotRecorder = ui.PictureRecorder();
    final rotCanvas = Canvas(rotRecorder, const Rect.fromLTWH(0, 0, 200, 100));
    rotCanvas.translate(100, 50); // new center is (200/2, 100/2)
    rotCanvas.rotate(3.141592653589793 / 2);
    rotCanvas.drawImage(original, const Offset(-50, -100), Paint());
    final rotPicture = rotRecorder.endRecording();
    final rotated = await rotPicture.toImage(200, 100);

    expect(rotated.width, 200);
    expect(rotated.height, 100);
  });
}
