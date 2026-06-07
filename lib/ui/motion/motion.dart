import 'package:flutter/material.dart';

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);
  static const Duration page = Duration(milliseconds: 300);
  static const Duration stagger = Duration(milliseconds: 50);

  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve emphasizedCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;

  static const Offset subtleRight = Offset(0.04, 0);
  static const Offset subtleLeft = Offset(-0.04, 0);
  static const Offset subtleUp = Offset(0, 0.08);
  static const Offset pageRight = Offset(1, 0);
}
