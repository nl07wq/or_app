import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../food_nutrition_formatter.dart';
import '../models/food_quantity_models.dart';
import '../services/food_input_capture_gateway.dart';
import '../services/food_live_capture_presenter.dart';
import '../services/japanese_nutrition_ocr_parser.dart';
import '../services/japanese_package_ocr_parser.dart';

enum FoodOcrMode { package, nutrition }

sealed class FoodOcrResult {
  const FoodOcrResult(this.rawText);
  final String rawText;
}

class FoodPackageOcrResult extends FoodOcrResult {
  const FoodPackageOcrResult(super.rawText, this.draft);
  final PackageOcrDraft draft;
}

class FoodNutritionOcrResult extends FoodOcrResult {
  const FoodNutritionOcrResult(super.rawText, this.draft);
  final NutritionOcrDraft draft;
}

Future<FoodOcrResult?> showFoodOcrScanner({
  required BuildContext context,
  required FoodInputCaptureGateway gateway,
}) async {
  final mode = await _chooseMode(context);
  if (mode == null || !context.mounted) return null;
  final captureMode = await _chooseCaptureMode(context);
  if (captureMode == null || !context.mounted) return null;

  final String? rawText;
  NutritionOcrDraft? nutritionDraft;
  PackageOcrDraft? packageDraft;
  if (captureMode == FoodNutritionCaptureMode.live) {
    if (gateway is! FoodLiveCaptureGateway) {
      throw UnsupportedError('Live OCR capture is unavailable.');
    }
    if (mode == FoodOcrMode.nutrition) {
      final session = FoodNutritionCandidateSession();
      rawText = await gateway.recognizeTextLive(
        title: 'NUTRITION OCR',
        instruction: '栄養成分表示を枠内に合わせてください',
        describeCandidate: session.describe,
      );
      nutritionDraft = session.draft;
    } else {
      final session = _PackageCandidateSession();
      rawText = await gateway.recognizeTextLive(
        title: 'PACKAGE OCR',
        instruction: '商品名・ブランド・内容量を枠内に合わせてください',
        describeCandidate: session.describe,
      );
      packageDraft = session.draft;
    }
  } else {
    final image = await gateway.selectImage(
      captureMode == FoodNutritionCaptureMode.camera
          ? FoodImageSource.camera
          : FoodImageSource.gallery,
    );
    if (image == null) return null;
    rawText = await gateway.recognizeJapaneseText(image);
  }
  if (rawText == null || !context.mounted) return null;

  if (mode == FoodOcrMode.nutrition) {
    final draft = nutritionDraft?.isEmpty == false
        ? nutritionDraft!
        : const JapaneseNutritionOcrParser().parse(rawText);
    if (draft.isEmpty) return null;
    final apply = await _reviewNutrition(context, draft);
    return apply ? FoodNutritionOcrResult(rawText, draft) : null;
  }
  final draft = packageDraft?.isEmpty == false
      ? packageDraft!
      : const JapanesePackageOcrParser().parse(rawText);
  if (draft.isEmpty) return null;
  final apply = await _reviewPackage(context, draft);
  return apply ? FoodPackageOcrResult(rawText, draft) : null;
}

Future<FoodOcrMode?> _chooseMode(BuildContext context) =>
    showModalBottomSheet<FoodOcrMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('何を読み取りますか？')),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('PACKAGE'),
              subtitle: const Text('商品名・ブランド・内容量など'),
              onTap: () => Navigator.pop(context, FoodOcrMode.package),
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart_outline),
              title: const Text('NUTRITION'),
              subtitle: const Text('栄養基準量・カロリー・PFC'),
              onTap: () => Navigator.pop(context, FoodOcrMode.nutrition),
            ),
          ],
        ),
      ),
    );

Future<FoodNutritionCaptureMode?> _chooseCaptureMode(BuildContext context) =>
    showModalBottomSheet<FoodNutritionCaptureMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.center_focus_strong),
              title: const Text('LIVE SCAN'),
              onTap: () =>
                  Navigator.pop(context, FoodNutritionCaptureMode.live),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('CAMERA'),
              onTap: () =>
                  Navigator.pop(context, FoodNutritionCaptureMode.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('PHOTO LIBRARY'),
              onTap: () =>
                  Navigator.pop(context, FoodNutritionCaptureMode.gallery),
            ),
          ],
        ),
      ),
    );

Future<bool> _reviewNutrition(
  BuildContext context,
  NutritionOcrDraft draft,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('REVIEW NUTRITION'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _value(
                'NUTRITION BASIS',
                _quantity(draft.basisQuantity, draft.basisUnit),
              ),
              _value('CALORIES', _amount(draft.calories, 'kcal')),
              _value('PROTEIN', _amount(draft.protein, 'g')),
              _value('FAT', _amount(draft.fat, 'g')),
              _value('CARBOHYDRATE', _amount(draft.carbohydrate, 'g')),
            ],
          ),
        ),
        actions: _actions(context),
      ),
    ) ??
    false;

Future<bool> _reviewPackage(
  BuildContext context,
  PackageOcrDraft draft,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('REVIEW PACKAGE'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _value('NAME', draft.name),
              _value('BRAND', draft.brand),
              _value(
                'PACKAGE',
                _quantity(draft.packageQuantity, draft.packageUnit),
              ),
            ],
          ),
        ),
        actions: _actions(context),
      ),
    ) ??
    false;

List<Widget> _actions(BuildContext context) => [
  TextButton(
    onPressed: () => Navigator.pop(context, false),
    child: const Text('CANCEL'),
  ),
  FilledButton(
    onPressed: () => Navigator.pop(context, true),
    child: const Text('APPLY TO FORM'),
  ),
];

Widget _value(String label, String? value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
  child: Text('$label  ${value ?? 'NEEDS REVIEW'}'),
);

String? _amount(double? value, String suffix) =>
    value == null ? null : '${FoodNutritionFormatter.amount(value)} $suffix';

String? _quantity(double? value, FoodQuantityUnit? unit) {
  if (value == null || unit == null) return null;
  return '${FoodNutritionFormatter.amount(value)} ${switch (unit) {
    FoodQuantityUnit.gram => 'g',
    FoodQuantityUnit.milliliter => 'mL',
    FoodQuantityUnit.piece => 'piece',
    FoodQuantityUnit.pack => 'pack',
    FoodQuantityUnit.serving => 'serving',
  }}';
}

class _PackageCandidateSession {
  PackageOcrDraft _draft = const PackageOcrDraft();
  PackageOcrDraft get draft => _draft;

  FoodOcrLiveCandidate describe(String rawText) {
    final next = const JapanesePackageOcrParser().parse(rawText);
    _draft = PackageOcrDraft(
      name: next.name ?? _draft.name,
      brand: next.brand ?? _draft.brand,
      packageQuantity: next.packageQuantity ?? _draft.packageQuantity,
      packageUnit: next.packageUnit ?? _draft.packageUnit,
    );
    return FoodOcrLiveCandidate(
      state: _draft.isEmpty ? 'scanning' : 'partial',
      fields: {
        'NAME': _draft.name,
        'BRAND': _draft.brand,
        'PACKAGE': _quantity(_draft.packageQuantity, _draft.packageUnit),
      },
    );
  }
}
