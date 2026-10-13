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

  testWidgets('Check InteractiveViewer position and crop mapping', (tester) async {
    Key childKey = const Key('child');
    final controller = TransformationController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 500,
          height: 500,
          child: InteractiveViewer(
            transformationController: controller,
            constrained: false,
            child: SizedBox(
              key: childKey,
              width: 2000,
              height: 1000,
              child: Container(),
            ),
          ),
        ),
      ),
    );
    final renderBox = tester.renderObject(find.byKey(childKey)) as RenderBox;
    final pos = renderBox.localToGlobal(Offset.zero);
    print('DEBUG: Child size: ${renderBox.size}, pos: $pos, transform: ${controller.value}');
  });

  test('Verify pixel crop matches screen circle', () async {
    // Create a 200x200 test image: left half RED, right half BLUE
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 200, 200));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 200), Paint()..color = const Color(0xFFFF0000));
    canvas.drawRect(const Rect.fromLTWH(100, 0, 100, 200), Paint()..color = const Color(0xFF0000FF));
    final testImage = await recorder.endRecording().toImage(200, 200);

    const vpWidth = 400.0;
    const vpHeight = 400.0;
    const circleRadius = 100.0;
    const outSize = 200.0;

    // Image is 200x200. Circle is radius 100, centered at (200, 200).
    // Circle covers (100, 100) to (300, 300).
    // If we center the image at (200, 200) with scale 1.0:
    // tx = (400 - 200) / 2 = 100, ty = (400 - 200) / 2 = 100.
    final matrix = Matrix4.identity()..translate(100.0, 100.0)..scale(1.0);

    // Output crop:
    final cropRecorder = ui.PictureRecorder();
    final cropCanvas = Canvas(cropRecorder, const Rect.fromLTWH(0, 0, outSize, outSize));
    final circlePath = Path()..addOval(const Rect.fromLTWH(0, 0, outSize, outSize));
    cropCanvas.clipPath(circlePath);

    cropCanvas.save();
    cropCanvas.translate(outSize / 2, outSize / 2);
    cropCanvas.scale(outSize / (2 * circleRadius));
    cropCanvas.translate(-vpWidth / 2, -vpHeight / 2);
    cropCanvas.transform(matrix.storage);
    cropCanvas.drawImageRect(
      testImage,
      const Rect.fromLTWH(0, 0, 200, 200),
      const Rect.fromLTWH(0, 0, 200, 200),
      Paint()..isAntiAlias = true,
    );
    cropCanvas.restore();

    final result = await cropRecorder.endRecording().toImage(200, 200);
    final bd = await result.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(bd, isNotNull);
    
    // Pixel at (50, 100) (left half of output) should be RED
    // Pixel at (150, 100) (right half of output) should be BLUE
    final leftPixelIndex = (100 * 200 + 50) * 4;
    final rLeft = bd!.getUint8(leftPixelIndex);
    final bLeft = bd.getUint8(leftPixelIndex + 2);
    print('Left pixel RGBA: r=$rLeft, b=$bLeft');
    expect(rLeft, greaterThan(200)); // Red
    expect(bLeft, lessThan(50));

    final rightPixelIndex = (100 * 200 + 150) * 4;
    final rRight = bd.getUint8(rightPixelIndex);
    final bRight = bd.getUint8(rightPixelIndex + 2);
    print('Right pixel RGBA: r=$rRight, b=$bRight');
    expect(rRight, lessThan(50));
    expect(bRight, greaterThan(200)); // Blue
  });

}
