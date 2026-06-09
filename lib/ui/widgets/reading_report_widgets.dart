import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/reading_report.dart';

class ReportSectionCard extends StatelessWidget {
  const ReportSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.color = Colors.blue,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class ReportMetricGrid extends StatelessWidget {
  const ReportMetricGrid({
    super.key,
    required this.items,
  });

  final List<ReportMetricTileData> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _ReportMetricTile(item: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class ReportMetricTileData {
  const ReportMetricTileData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _ReportMetricTile extends StatelessWidget {
  const _ReportMetricTile({required this.item});

  final ReportMetricTileData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.color.withAlpha(24),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: item.color, size: 22),
          const SizedBox(height: 8),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[850],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class ReadingMetricBars extends StatelessWidget {
  const ReadingMetricBars({
    super.key,
    required this.items,
    required this.color,
    this.emptyText = '暂无数据',
  });

  final List<ReadingMetricItem> items;
  final Color color;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        emptyText,
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      );
    }

    final maxCount = items.fold<int>(
      1,
      (max, item) => item.count > max ? item.count : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.count}次',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: item.count / maxCount,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
                color: color,
                backgroundColor: color.withAlpha(28),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class ReadingTrendChart extends StatelessWidget {
  const ReadingTrendChart({
    super.key,
    required this.items,
    required this.color,
  });

  final List<ReadingTrendItem> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxCount = items.fold<int>(
      1,
      (max, item) => item.count > max ? item.count : max,
    );
    return SizedBox(
      height: 150,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: items.map((item) {
            final height = 18 + item.count / maxCount * 66;
            return SizedBox(
              width: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 18,
                      child: Text(
                        '${item.count}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 84,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          height: height,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 20,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class InterestRadarChart extends StatelessWidget {
  const InterestRadarChart({
    super.key,
    required this.items,
    required this.color,
  });

  final List<ReadingMetricItem> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            '暂无兴趣样本',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: CustomPaint(
        painter: _InterestRadarPainter(
          items: items.take(6).toList(),
          color: color,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _InterestRadarPainter extends CustomPainter {
  const _InterestRadarPainter({
    required this.items,
    required this.color,
  });

  final List<ReadingMetricItem> items;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final count = items.length;
    if (count == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.31;
    final maxCount = items.fold<int>(
      1,
      (max, item) => item.count > max ? item.count : max,
    );
    final gridPaint = Paint()
      ..color = Colors.grey.withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.grey.withAlpha(85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..color = color.withAlpha(48)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var level = 1; level <= 3; level++) {
      final path = Path();
      for (var index = 0; index < count; index++) {
        final point = _point(
          center,
          radius * level / 3,
          index,
          count,
        );
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    final valuePath = Path();
    for (var index = 0; index < count; index++) {
      final outerPoint = _point(center, radius, index, count);
      canvas.drawLine(center, outerPoint, axisPaint);

      final valueRadius = radius * (items[index].count / maxCount);
      final valuePoint = _point(center, valueRadius, index, count);
      if (index == 0) {
        valuePath.moveTo(valuePoint.dx, valuePoint.dy);
      } else {
        valuePath.lineTo(valuePoint.dx, valuePoint.dy);
      }

      _drawLabel(canvas, size, center, radius, index, count, items[index]);
    }
    valuePath.close();
    canvas.drawPath(valuePath, fillPaint);
    canvas.drawPath(valuePath, strokePaint);
  }

  Offset _point(Offset center, double radius, int index, int count) {
    final angle = -math.pi / 2 + index * math.pi * 2 / count;
    return Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    int index,
    int count,
    ReadingMetricItem item,
  ) {
    final point = _point(center, radius + 32, index, count);
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${item.label}\n${item.count}次',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 11,
          height: 1.25,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: 72);
    final offset = Offset(
      point.dx - textPainter.width / 2,
      point.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _InterestRadarPainter oldDelegate) {
    return oldDelegate.items != items || oldDelegate.color != color;
  }
}
