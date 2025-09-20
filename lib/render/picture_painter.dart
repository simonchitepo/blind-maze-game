import 'dart:ui';
import 'package:flutter/material.dart';

class PicturePainter extends CustomPainter {
  final Picture? picture;
  PicturePainter(this.picture);

  @override
  void paint(Canvas canvas, Size size) {
    if (picture == null) return;
    canvas.drawPicture(picture!);
  }

  @override
  bool shouldRepaint(covariant PicturePainter oldDelegate) =>
      oldDelegate.picture != picture;
}
