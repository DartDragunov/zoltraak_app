import 'package:flutter/material.dart';

class RoadSegment {
  final Offset p0, p1, p2, p3;
  const RoadSegment(this.p0, this.p1, this.p2, this.p3);

  Offset point(double t) {
    final mt = 1 - t;
    return Offset(
      mt * mt * mt * p0.dx +
          3 * mt * mt * t * p1.dx +
          3 * mt * t * t * p2.dx +
          t * t * t * p3.dx,
      mt * mt * mt * p0.dy +
          3 * mt * mt * t * p1.dy +
          3 * mt * t * t * p2.dy +
          t * t * t * p3.dy,
    );
  }

  Offset tangent(double t) {
    final mt = 1 - t;
    return Offset(
      3 *
          (mt * mt * (p1.dx - p0.dx) +
              2 * mt * t * (p2.dx - p1.dx) +
              t * t * (p3.dx - p2.dx)),
      3 *
          (mt * mt * (p1.dy - p0.dy) +
              2 * mt * t * (p2.dy - p1.dy) +
              t * t * (p3.dy - p2.dy)),
    );
  }
}
