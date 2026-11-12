import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:or_app/core/theme/app_spacing.dart';

const baseCampStatusEntryAsset =
    'assets/images/themes/base_camp/entry/status.jpg';
const baseCampActivityEntryAsset =
    'assets/images/themes/base_camp/entry/activity.jpg';
const baseCampFoodEntryAsset = 'assets/images/themes/base_camp/entry/food.jpg';
const baseCampTrainingEntryAsset =
    'assets/images/themes/base_camp/entry/training.jpg';
const baseCampCommandCenterEntryAsset =
    'assets/images/themes/base_camp/entry/command_center.jpg';

/// Static BASE CAMP facility entrance used only by the five map modules.
/// Business actions are supplied by the existing feature pages so this layer
/// never owns or copies formal records.
class BaseCampFacilityEntryPage extends StatelessWidget {
  const BaseCampFacilityEntryPage({
    super.key,
    required this.title,
    required this.imageAsset,
    required this.actions,
  });

  final String title;
  final String imageAsset;
  final List<BaseCampFacilityEntryAction> actions;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final cacheWidth = math
        .max(512, mediaQuery.size.width * mediaQuery.devicePixelRatio)
        .round()
        .clamp(512, 1536);
    return Scaffold(
      key: ValueKey('base-camp-${title.toLowerCase()}-facility-entry'),
      backgroundColor: const Color(0xff11150f),
      appBar: AppBar(
        backgroundColor: const Color(0xff1a2016),
        foregroundColor: const Color(0xffe8e2c9),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Text(title),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = math.min(
            constraints.maxWidth * 9 / 16,
            constraints.maxHeight * .27,
          );
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              mediaQuery.padding.bottom + AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: imageHeight,
                    constraints: const BoxConstraints(minHeight: 132),
                    foregroundDecoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xff77745b),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      imageAsset,
                      key: ValueKey('base-camp-facility-image-$title'),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      cacheWidth: cacheWidth,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: Color(0xff20251b),
                            child: Center(
                              child: Text(
                                'FACILITY IMAGE UNAVAILABLE',
                                style: TextStyle(color: Color(0xffc8c2a6)),
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
                AppSpacing.gapLG,
                for (var index = 0; index < actions.length; index++) ...[
                  actions[index],
                  if (index != actions.length - 1) AppSpacing.gapLG,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class BaseCampFacilityEntryAction extends StatelessWidget {
  const BaseCampFacilityEntryAction({
    super.key,
    required this.description,
    required this.child,
  });

  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xff1b2117),
      border: Border.all(color: const Color(0xff53543f)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xffc8c2a6),
              height: 1.35,
            ),
          ),
          AppSpacing.gapSM,
          child,
        ],
      ),
    ),
  );
}
