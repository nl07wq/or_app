import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../food_nutrition_formatter.dart';
import '../models/nutrition_models.dart';

const double foodDetailPfcRingWidth = 18;
const Color foodDetailProteinColor = Color(0xFF63D8FF);
const Color foodDetailFatColor = Color(0xFF7EA8FF);
const Color foodDetailCarbohydrateColor = Color(0xFF9B8CFF);
const Color _legacyProteinColor = Color(0xFFE08AAA);
const Color _legacyFatColor = Color(0xFFE9A052);
const Color _legacyCarbohydrateColor = Color(0xFF62BFE3);

/// Immutable, presentation-only token set for the FOOD DETAIL PFC card.
@immutable
class FoodPfcBalanceStyle {
  const FoodPfcBalanceStyle({
    required this.colors,
    required this.trackColor,
    required this.dividerColor,
    required this.ringWidth,
    required this.donutSize,
    required this.cardDecoration,
  });

  final List<Color> colors;
  final Color trackColor;
  final Color dividerColor;
  final double ringWidth;
  final double donutSize;
  final BoxDecoration cardDecoration;

  static const foodDetail = FoodPfcBalanceStyle(
    colors: [
      foodDetailProteinColor,
      foodDetailFatColor,
      foodDetailCarbohydrateColor,
    ],
    trackColor: Color(0xFF233140),
    dividerColor: Color(0xFF2A4254),
    ringWidth: foodDetailPfcRingWidth,
    donutSize: 112,
    cardDecoration: BoxDecoration(
      color: Color(0xCC141D27),
      borderRadius: BorderRadius.all(Radius.circular(19)),
      border: Border.fromBorderSide(BorderSide(color: Color(0xFF304659))),
    ),
  );
}

class FoodPfcBalanceCard extends StatelessWidget {
  const FoodPfcBalanceCard({
    super.key,
    required this.nutrition,
    this.title = 'PFC BALANCE',
    this.keyPrefix = 'food-detail-pfc',
    this.style,
  });

  final NutritionSnapshot nutrition;
  final String title;
  final String keyPrefix;
  final FoodPfcBalanceStyle? style;

  static bool hasBalance(NutritionSnapshot nutrition) =>
      nutrition.protein != null &&
      nutrition.fat != null &&
      nutrition.carbohydrate != null &&
      nutrition.protein! * 4 +
              nutrition.fat! * 9 +
              nutrition.carbohydrate! * 4 >
          0;

  @override
  Widget build(BuildContext context) {
    final grams = [nutrition.protein!, nutrition.fat!, nutrition.carbohydrate!];
    final values = [grams[0] * 4, grams[1] * 9, grams[2] * 4];
    final total = values.reduce((a, b) => a + b);
    const legacyColors = [
      _legacyProteinColor,
      _legacyFatColor,
      _legacyCarbohydrateColor,
    ];
    const labels = ['PROTEIN', 'FAT', 'CARBOHYDRATE'];
    final detailStyle = style;
    final detail = detailStyle != null;
    final colors = detailStyle?.colors ?? legacyColors;
    final ringWidth = detailStyle?.ringWidth ?? 12.0;
    final donutSize = detailStyle?.donutSize ?? 104.0;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detail) ...[
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF1F7FF),
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          AppSpacing.gapSM,
          Divider(color: detailStyle.dividerColor, height: 1),
          AppSpacing.gapMD,
        ] else ...[
          SectionHeader(icon: Icons.donut_large, title: title),
          AppSpacing.gapSM,
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final compactDetail = detail && constraints.maxWidth < 280;
            final donut = _donut(
              values,
              colors,
              detailStyle,
              detail,
              ringWidth,
              donutSize,
            );
            final metrics = _metrics(
              context,
              labels,
              grams,
              values,
              total,
              colors,
              detailStyle,
              detail,
            );
            if (compactDetail) {
              return Column(
                key: ValueKey('$keyPrefix-horizontal'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: donut),
                  AppSpacing.gapMD,
                  metrics,
                ],
              );
            }
            return Row(
              key: ValueKey('$keyPrefix-horizontal'),
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                donut,
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: metrics),
              ],
            );
          },
        ),
      ],
    );
    if (!detail) {
      return OperationCard(key: ValueKey('$keyPrefix-card'), child: content);
    }
    return Container(
      key: ValueKey('$keyPrefix-card'),
      decoration: detailStyle.cardDecoration,
      padding: AppSpacing.cardPadding,
      child: content,
    );
  }

  Widget _donut(
    List<double> values,
    List<Color> colors,
    FoodPfcBalanceStyle? detailStyle,
    bool detail,
    double ringWidth,
    double donutSize,
  ) => SizedBox(
    key: ValueKey('$keyPrefix-donut'),
    width: donutSize,
    height: donutSize,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _PfcPainter(
            values,
            colors,
            trackColor: detailStyle?.trackColor ?? Colors.transparent,
            ringWidth: ringWidth,
            inset: detail ? ringWidth / 2 : 10,
            drawTrack: detail,
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    nutrition.calories == null
                        ? 'N/A'
                        : FoodNutritionFormatter.calories(nutrition.calories!),
                    key: ValueKey('$keyPrefix-center-calories'),
                    maxLines: 1,
                    style: TextStyle(
                      color: detail ? const Color(0xFFF1F7FF) : null,
                      fontSize: detail ? 24 : 18,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
                if (nutrition.calories != null)
                  Text(
                    'kcal',
                    style: TextStyle(
                      color: detail ? const Color(0xFFF1F7FF) : null,
                      fontSize: detail ? 11 : 10,
                      height: 1.1,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _metrics(
    BuildContext context,
    List<String> labels,
    List<double> grams,
    List<double> values,
    double total,
    List<Color> colors,
    FoodPfcBalanceStyle? detailStyle,
    bool detail,
  ) => Column(
    children: [
      for (var index = 0; index < values.length; index++) ...[
        _PfcMetricRow(
          key: ValueKey('$keyPrefix-${labels[index]}'),
          label: labels[index],
          grams: grams[index],
          percent: (values[index] / total * 100).round(),
          color: colors[index],
          textColor: detail
              ? const Color(0xFFF1F7FF)
              : Theme.of(context).colorScheme.onSurface,
          emphasized: detail,
          dotKey: ValueKey('$keyPrefix-${labels[index]}-dot'),
        ),
        if (index < values.length - 1)
          detail
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Divider(color: detailStyle!.dividerColor, height: 1),
                )
              : AppSpacing.gapSM,
      ],
    ],
  );
}

class _PfcMetricRow extends StatelessWidget {
  const _PfcMetricRow({
    super.key,
    required this.label,
    required this.grams,
    required this.percent,
    required this.color,
    required this.textColor,
    required this.emphasized,
    required this.dotKey,
  });

  final String label;
  final double grams;
  final int percent;
  final Color color;
  final Color textColor;
  final bool emphasized;
  final Key dotKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labelStyle = TextStyle(
        color: textColor,
        fontWeight: FontWeight.w700,
      );
      final compact = constraints.maxWidth < 190;
      final gramsWidth = emphasized
          ? (compact ? 72.0 : 80.0)
          : (compact ? 48.0 : 58.0);
      final percentWidth = emphasized
          ? (compact ? 42.0 : 46.0)
          : (compact ? 34.0 : 36.0);
      return Row(
        children: [
          Container(
            key: dotKey,
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, maxLines: 1, style: labelStyle),
            ),
          ),
          SizedBox(
            width: gramsWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: FoodNutritionFormatter.macro(grams),
                      style: TextStyle(
                        color: emphasized ? color : textColor,
                        fontSize: emphasized ? 15 : null,
                        fontWeight: emphasized
                            ? FontWeight.w700
                            : FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' g',
                      style: TextStyle(
                        color: emphasized ? color : textColor,
                        fontSize: emphasized ? 12 : null,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
          ),
          SizedBox(
            width: percentWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$percent%',
                maxLines: 1,
                style: TextStyle(
                  color: textColor,
                  fontSize: emphasized ? 14 : null,
                  fontWeight: emphasized ? FontWeight.w600 : FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PfcPainter extends CustomPainter {
  const _PfcPainter(
    this.values,
    this.colors, {
    required this.trackColor,
    required this.ringWidth,
    required this.inset,
    required this.drawTrack,
  });

  final List<double> values;
  final List<Color> colors;
  final Color trackColor;
  final double ringWidth;
  final double inset;
  final bool drawTrack;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.reduce((a, b) => a + b);
    final rect = (Offset.zero & size).deflate(inset);
    if (drawTrack) {
      canvas.drawCircle(
        size.center(Offset.zero),
        rect.width / 2,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..strokeCap = StrokeCap.butt,
      );
    }
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = math.pi * 2 * values[index] / total;
      if (drawTrack) {
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = colors[index].withValues(alpha: .14)
            ..style = PaintingStyle.stroke
            ..strokeWidth = ringWidth + 4
            ..strokeCap = StrokeCap.butt,
        );
      }
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = colors[index]
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PfcPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.colors != colors ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.ringWidth != ringWidth ||
      oldDelegate.inset != inset ||
      oldDelegate.drawTrack != drawTrack;
}
