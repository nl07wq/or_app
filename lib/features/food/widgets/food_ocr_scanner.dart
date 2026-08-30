import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../food_nutrition_formatter.dart';
import '../models/food_quantity_models.dart';
import '../services/food_input_capture_gateway.dart';
import '../services/food_live_capture_presenter.dart';
import '../services/japanese_nutrition_ocr_parser.dart';
import '../services/japanese_package_ocr_parser.dart';

sealed class FoodOcrResult {
  const FoodOcrResult(this.rawText);
  final String rawText;
}

class FoodPackageOcrResult extends FoodOcrResult {
  const FoodPackageOcrResult(super.rawText, this.draft);
  final PackageOcrDraft draft;
}

class FoodNutritionOcrResult extends FoodOcrResult {
  const FoodNutritionOcrResult(
    super.rawText,
    this.draft, {
    this.engine = FoodOcrEngine.tesseract,
  });
  final NutritionOcrDraft draft;
  final FoodOcrEngine engine;
}

/// Opens the user-facing scanner for known fields in a nutrition label.
///
/// Package-front OCR is intentionally not exposed here. Its browser OCR
/// implementation remains available only for isolated tests while the feature
/// is semi-permanently pending (see `docs/food_ocr_scope.md`).
Future<FoodOcrResult?> showNutritionLabelScanner({
  required BuildContext context,
  required FoodInputCaptureGateway gateway,
}) async {
  final engine = await _chooseOcrEngine(context);
  if (engine == null || !context.mounted) return null;

  while (context.mounted) {
    if (!context.mounted) return null;
    final capture = await _captureNutrition(
      context: context,
      gateway: gateway,
      engine: engine,
    );
    if (capture == null || !context.mounted) return null;
    final parsed = capture.draft?.isEmpty == false
        ? (draft: capture.draft!, conflicts: capture.conflicts)
        : _nutritionDraft(capture.rawText);
    if (parsed.draft.isEmpty) return null;
    final action = await _reviewNutrition(
      context,
      parsed.draft,
      parsed.conflicts,
      engine,
    );
    if (action == _NutritionReviewAction.rescan) continue;
    if (action != _NutritionReviewAction.apply) return null;
    return FoodNutritionOcrResult(
      capture.rawText,
      parsed.draft,
      engine: engine,
    );
  }
  return null;
}

Future<
  ({
    String rawText,
    NutritionOcrDraft? draft,
    Set<String> conflicts,
  })?
>
_captureNutrition({
  required BuildContext context,
  required FoodInputCaptureGateway gateway,
  required FoodOcrEngine engine,
}) async {
  if (gateway case final FoodLiveCaptureGateway liveGateway) {
    final session = FoodNutritionCandidateSession();
    final rawText = await liveGateway.recognizeTextLive(
      title: 'NUTRITION LABEL SCAN',
      instruction: '栄養成分表示を枠内に入れてください',
      describeCandidate: session.describe,
      engine: engine,
    );
    if (rawText == null) return null;
    for (final pass in _ocrPasses(rawText)) {
      session.describe(pass);
    }
    return (
      rawText: rawText,
      draft: session.draft,
      conflicts: session.conflicts,
    );
  }

  final source = await _chooseStillImageSource(context);
  if (source == null) return null;
  final image = await gateway.selectImage(source);
  if (image == null) return null;
  final rawText = await gateway.recognizeJapaneseText(
    image,
    mode: FoodTextOcrMode.nutrition,
    engine: engine,
  );
  return (rawText: rawText, draft: null, conflicts: const <String>{});
}

@visibleForTesting
Future<FoodOcrResult?> showPackageOcrScannerForTesting({
  required BuildContext context,
  required FoodInputCaptureGateway gateway,
}) => _showPackageOcrScanner(context: context, gateway: gateway);

Future<FoodOcrResult?> _showPackageOcrScanner({
  required BuildContext context,
  required FoodInputCaptureGateway gateway,
}) async {
  final captureMode = await _chooseCaptureMode(context);
  if (captureMode == null || !context.mounted) return null;

  final String? rawText;
  PackageOcrDraft? packageDraft;
  if (captureMode == FoodNutritionCaptureMode.live) {
    if (gateway is! FoodLiveCaptureGateway) {
      throw UnsupportedError('Live OCR capture is unavailable.');
    }
    final session = _PackageCandidateSession();
    rawText = await gateway.recognizeTextLive(
      title: 'PACKAGE OCR',
      instruction: '商品名・ブランド・内容量を枠内に合わせてください',
      describeCandidate: session.describe,
    );
    if (rawText != null) {
      for (final pass in _ocrPasses(rawText)) {
        session.describe(pass);
      }
    }
    packageDraft = session.draft;
  } else {
    final image = await gateway.selectImage(
      captureMode == FoodNutritionCaptureMode.camera
          ? FoodImageSource.camera
          : FoodImageSource.gallery,
    );
    if (image == null) return null;
    rawText = await gateway.recognizeJapaneseText(
      image,
      mode: FoodTextOcrMode.package,
    );
  }
  if (rawText == null || !context.mounted) return null;

  final draft = packageDraft?.isEmpty == false
      ? packageDraft!
      : _packageDraft(rawText);
  if (draft.isEmpty) return null;
  final reviewed = await _reviewPackage(context, draft);
  return reviewed == null ? null : FoodPackageOcrResult(rawText, reviewed);
}

Iterable<String> _ocrPasses(String rawText) => rawText
    .split('\u001e')
    .map((pass) => pass.trim())
    .where((pass) => pass.isNotEmpty);

({NutritionOcrDraft draft, Set<String> conflicts}) _nutritionDraft(
  String rawText,
) {
  final session = FoodNutritionCandidateSession();
  for (final pass in _ocrPasses(rawText)) {
    session.describe(pass);
  }
  return (draft: session.draft, conflicts: session.conflicts);
}

PackageOcrDraft _packageDraft(String rawText) {
  final session = _PackageCandidateSession();
  for (final pass in _ocrPasses(rawText)) {
    session.describe(pass);
  }
  return session.draft;
}

Future<FoodOcrEngine?> _chooseOcrEngine(BuildContext context) =>
    showModalBottomSheet<FoodOcrEngine>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text('SELECT OCR ENGINE'),
            ),
            ListTile(
              key: const ValueKey('nutrition-engine-tesseract'),
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('TESSERACT'),
              subtitle: const Text('CURRENT COMPARISON BASELINE'),
              onTap: () => Navigator.pop(context, FoodOcrEngine.tesseract),
            ),
            ListTile(
              key: const ValueKey('nutrition-engine-paddle'),
              leading: const Icon(Icons.science_outlined),
              title: const Text('PADDLE PoC'),
              subtitle: const Text('EXPERIMENTAL COMPARISON'),
              onTap: () => Navigator.pop(context, FoodOcrEngine.paddle),
            ),
          ],
        ),
      ),
    );

Future<FoodImageSource?> _chooseStillImageSource(BuildContext context) =>
    showModalBottomSheet<FoodImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('CAMERA'),
              onTap: () => Navigator.pop(context, FoodImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('PHOTO LIBRARY'),
              onTap: () => Navigator.pop(context, FoodImageSource.gallery),
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

enum _NutritionReviewAction { cancel, rescan, apply }

Future<_NutritionReviewAction> _reviewNutrition(
  BuildContext context,
  NutritionOcrDraft draft,
  Set<String> conflicts,
  FoodOcrEngine engine,
) async =>
    await showDialog<_NutritionReviewAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('REVIEW NUTRITION'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _value('OCR ENGINE', engine.label),
              _value(
                'NUTRITION BASIS',
                _quantity(draft.basisQuantity, draft.basisUnit),
              ),
              _value('CALORIES', _amount(draft.calories, 'kcal')),
              _value('PROTEIN', _amount(draft.protein, 'g')),
              _value('FAT', _amount(draft.fat, 'g')),
              _value('CARBOHYDRATE', _amount(draft.carbohydrate, 'g')),
              if (conflicts.isNotEmpty)
                _value('REVIEW CONFLICT', conflicts.join(', ')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _NutritionReviewAction.cancel,
            ),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _NutritionReviewAction.rescan,
            ),
            child: const Text('RESCAN'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _NutritionReviewAction.apply,
            ),
            child: const Text('APPLY TO FORM'),
          ),
        ],
      ),
    ) ??
    _NutritionReviewAction.cancel;

Future<PackageOcrDraft?> _reviewPackage(
  BuildContext context,
  PackageOcrDraft draft,
) => showDialog<PackageOcrDraft>(
  context: context,
  builder: (context) => _PackageReviewDialog(draft: draft),
);

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
      nameCandidates: {
        ..._draft.nameCandidates,
        ...next.nameCandidates,
      }.toList(growable: false),
      brandCandidates: {
        ..._draft.brandCandidates,
        ...next.brandCandidates,
      }.toList(growable: false),
    );
    return FoodOcrLiveCandidate(
      state: _draft.isEmpty
          ? (rawText.trim().isEmpty ? 'scanning' : 'insufficient')
          : 'partial',
      fields: {
        'NAME': _draft.name,
        'BRAND': _draft.brand,
        'NAME CANDIDATES': _draft.nameCandidates.isEmpty
            ? null
            : _draft.nameCandidates.join(' / '),
        'BRAND CANDIDATES': _draft.brandCandidates.isEmpty
            ? null
            : _draft.brandCandidates.join(' / '),
        'PACKAGE': _quantity(_draft.packageQuantity, _draft.packageUnit),
      },
    );
  }
}

class _PackageReviewDialog extends StatefulWidget {
  const _PackageReviewDialog({required this.draft});

  final PackageOcrDraft draft;

  @override
  State<_PackageReviewDialog> createState() => _PackageReviewDialogState();
}

class _PackageReviewDialogState extends State<_PackageReviewDialog> {
  late final TextEditingController _name;
  late final TextEditingController _brand;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.draft.name);
    _brand = TextEditingController(text: widget.draft.brand);
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('REVIEW PACKAGE'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'SELECTED NAME'),
          ),
          _candidateChoices(
            'NAME CANDIDATES',
            widget.draft.nameCandidates,
            _name,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _brand,
            decoration: const InputDecoration(labelText: 'SELECTED BRAND'),
          ),
          _candidateChoices(
            'BRAND CANDIDATES',
            widget.draft.brandCandidates,
            _brand,
          ),
          const SizedBox(height: AppSpacing.sm),
          _value(
            'PACKAGE',
            _quantity(widget.draft.packageQuantity, widget.draft.packageUnit),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('CANCEL'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          PackageOcrDraft(
            name: _valueOrNull(_name.text),
            brand: _valueOrNull(_brand.text),
            packageQuantity: widget.draft.packageQuantity,
            packageUnit: widget.draft.packageUnit,
            nameCandidates: widget.draft.nameCandidates,
            brandCandidates: widget.draft.brandCandidates,
          ),
        ),
        child: const Text('APPLY TO FORM'),
      ),
    ],
  );

  Widget _candidateChoices(
    String label,
    List<String> candidates,
    TextEditingController controller,
  ) {
    if (candidates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(label),
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final candidate in candidates)
              ActionChip(
                label: Text(candidate),
                onPressed: () => setState(() => controller.text = candidate),
              ),
          ],
        ),
      ],
    );
  }
}

String? _valueOrNull(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
