import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../food_nutrition_formatter.dart';
import '../models/food_quantity_models.dart';
import '../services/food_input_capture_gateway.dart';
import '../services/food_ocr_diagnostic_report.dart';
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
    this.scanMode = FoodOcrScanMode.nutritionLabelReader,
  });
  final NutritionOcrDraft draft;
  final FoodOcrScanMode scanMode;
}

/// Opens the user-facing scanner for known fields in a nutrition label.
///
/// Package-front OCR is intentionally not exposed here. Its browser OCR
/// implementation remains available only for isolated tests while the feature
/// is semi-permanently pending (see `docs/food_ocr_scope.md`).
Future<FoodOcrResult?> showNutritionLabelScanner({
  required BuildContext context,
  required FoodInputCaptureGateway gateway,
  VoidCallback? onProcessingComplete,
}) async {
  final capture = await _captureNutrition(gateway: gateway);
  onProcessingComplete?.call();
  if (capture == null || !context.mounted) return null;
  final parsed = capture.draft?.isEmpty == false
      ? (
          draft: capture.draft!,
          conflicts: capture.conflicts,
          decisions: capture.decisions,
        )
      : _nutritionDraft(capture.rawText);
  final reviewed = await _reviewNutrition(
    context,
    draft: parsed.draft,
    conflicts: parsed.conflicts,
    decisions: parsed.decisions,
    image: capture.image,
  );
  if (reviewed == null) return null;
  return FoodNutritionOcrResult(
    capture.rawText,
    reviewed,
    scanMode: FoodOcrScanMode.nutritionLabelReader,
  );
}

Future<
  ({
    String rawText,
    FoodCapturedImage image,
    NutritionOcrDraft? draft,
    Set<String> conflicts,
    Map<String, Map<String, dynamic>> decisions,
  })?
>
_captureNutrition({required FoodInputCaptureGateway gateway}) async {
  // No capture hint: the native file picker owns Camera, Photos, and Files.
  final image = await gateway.selectImage(FoodImageSource.gallery);
  if (image == null) return null;
  final rawText = await gateway.recognizeJapaneseText(
    image,
    mode: FoodTextOcrMode.nutrition,
    engine: FoodOcrEngine.tesseract,
    scanMode: FoodOcrScanMode.nutritionLabelReader,
  );
  return (
    rawText: rawText,
    image: image,
    draft: null,
    conflicts: const <String>{},
    decisions: const <String, Map<String, dynamic>>{},
  );
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

({
  NutritionOcrDraft draft,
  Set<String> conflicts,
  Map<String, Map<String, dynamic>> decisions,
})
_nutritionDraft(String rawText) {
  final session = FoodNutritionCandidateSession();
  for (final pass in _ocrPasses(rawText)) {
    session.describe(pass);
  }
  return (
    draft: session.draft,
    conflicts: session.conflicts,
    decisions: session.fieldDecisions,
  );
}

PackageOcrDraft _packageDraft(String rawText) {
  final session = _PackageCandidateSession();
  for (final pass in _ocrPasses(rawText)) {
    session.describe(pass);
  }
  return session.draft;
}

/// Explicit developer-only entry. Normal Food scan always uses the Nutrition
/// Label Reader and never exposes engine selection.
Future<void> showNutritionOcrDiagnostics(
  BuildContext context,
  FoodInputCaptureGateway gateway,
) async {
  final FoodOcrDiagnosticGateway? diagnosticGateway =
      gateway is FoodOcrDiagnosticGateway
      ? gateway as FoodOcrDiagnosticGateway
      : null;
  if (diagnosticGateway == null) return;
  final source = FoodImageSource.gallery;
  final image = await gateway.selectImage(source);
  if (image == null || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(width: AppSpacing.md),
          Text('RUNNING OCR DIAGNOSTICS'),
        ],
      ),
    ),
  );
  Map<String, dynamic> diagnostics;
  try {
    diagnostics = await diagnosticGateway.diagnoseNutritionImage(
      image,
      source: source,
    );
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
  if (!context.mounted) return;

  final formatted = formatFoodOcrDiagnosticReport(diagnostics);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('OCR DIAGNOSTICS'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(child: SelectableText(formatted)),
      ),
      actions: [
        if (_diagnosticPreview(diagnostics, 'standard') case final preview?)
          TextButton(
            key: const ValueKey('view-standard-ocr-input'),
            onPressed: () => showDialog<void>(
              context: dialogContext,
              builder: (previewContext) => AlertDialog(
                title: const Text('STANDARD OCR INPUT'),
                content: InteractiveViewer(child: _diagnosticImage(preview)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(previewContext),
                    child: const Text('CLOSE'),
                  ),
                ],
              ),
            ),
            child: const Text('VIEW STANDARD INPUT'),
          ),
        if (_diagnosticPreview(diagnostics, 'nutritionLabelReader')
            case final preview?)
          TextButton(
            key: const ValueKey('view-nutrition-ocr-input'),
            onPressed: () => showDialog<void>(
              context: dialogContext,
              builder: (previewContext) => AlertDialog(
                title: const Text('NUTRITION OCR INPUT'),
                content: InteractiveViewer(child: _diagnosticImage(preview)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(previewContext),
                    child: const Text('CLOSE'),
                  ),
                ],
              ),
            ),
            child: const Text('VIEW NUTRITION INPUT'),
          ),
        TextButton(
          key: const ValueKey('copy-ocr-diagnostics'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: formatted));
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('OCR diagnostics copied')),
              );
            }
          },
          child: const Text('COPY OCR DIAGNOSTICS'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('CLOSE'),
        ),
      ],
    ),
  );
}

String? _diagnosticPreview(Map<String, dynamic> diagnostics, String mode) {
  final branch = diagnostics[mode];
  if (branch is! Map) return null;
  final preview = branch['inputPreviewDataUrl'];
  return preview is String && preview.startsWith('data:image/')
      ? preview
      : null;
}

Widget _diagnosticImage(String dataUrl) {
  final separator = dataUrl.indexOf(',');
  return Image.memory(base64Decode(dataUrl.substring(separator + 1)));
}

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

Future<NutritionOcrDraft?> _reviewNutrition(
  BuildContext context, {
  required NutritionOcrDraft draft,
  required Set<String> conflicts,
  required Map<String, Map<String, dynamic>> decisions,
  required FoodCapturedImage image,
}) => showDialog<NutritionOcrDraft>(
  context: context,
  builder: (_) => _NutritionPreviewDialog(
    draft: _previewDraft(draft, conflicts, decisions),
    reviewFields: _previewReviewFields(conflicts, decisions),
    image: image,
  ),
);

NutritionOcrDraft _previewDraft(
  NutritionOcrDraft draft,
  Set<String> conflicts,
  Map<String, Map<String, dynamic>> decisions,
) => NutritionOcrDraft(
  basisQuantity: draft.basisQuantity,
  basisUnit: draft.basisUnit,
  calories: _previewValue('ENERGY', draft.calories, conflicts, decisions),
  protein: _previewValue('PROTEIN', draft.protein, conflicts, decisions),
  fat: _previewValue('FAT', draft.fat, conflicts, decisions),
  carbohydrate: _previewValue(
    'CARBOHYDRATE',
    draft.carbohydrate,
    conflicts,
    decisions,
  ),
  packageQuantity: draft.packageQuantity,
  packageUnit: draft.packageUnit,
);

double? _previewValue(
  String field,
  double? accepted,
  Set<String> conflicts,
  Map<String, Map<String, dynamic>> decisions,
) {
  if (conflicts.contains(field)) return null;
  if (accepted != null) return accepted;
  final decision = decisions[field];
  final value = decision?['value'];
  final expectedUnit = field == 'ENERGY' ? 'kcal' : 'g';
  if (decision?['conflict'] == true ||
      decision?['unit'] != expectedUnit ||
      value is! num ||
      !value.isFinite) {
    return null;
  }
  // This is a retained, field-owned OCR review candidate, never a guess.
  return value.toDouble();
}

Set<String> _previewReviewFields(
  Set<String> conflicts,
  Map<String, Map<String, dynamic>> decisions,
) => {
  ...conflicts,
  for (final entry in decisions.entries)
    if (entry.value['reviewRequired'] == true ||
        entry.value['conflict'] == true)
      entry.key,
};

class _NutritionPreviewDialog extends StatefulWidget {
  const _NutritionPreviewDialog({
    required this.draft,
    required this.reviewFields,
    required this.image,
  });

  final NutritionOcrDraft draft;
  final Set<String> reviewFields;
  final FoodCapturedImage image;

  @override
  State<_NutritionPreviewDialog> createState() =>
      _NutritionPreviewDialogState();
}

class _NutritionPreviewDialogState extends State<_NutritionPreviewDialog> {
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _fat;
  late final TextEditingController _carbohydrate;
  late final Set<String> _observedFields;

  @override
  void initState() {
    super.initState();
    _calories = _numberController(widget.draft.calories);
    _protein = _numberController(widget.draft.protein);
    _fat = _numberController(widget.draft.fat);
    _carbohydrate = _numberController(widget.draft.carbohydrate);
    _observedFields = {
      if (widget.draft.calories != null) 'ENERGY',
      if (widget.draft.protein != null) 'PROTEIN',
      if (widget.draft.fat != null) 'FAT',
      if (widget.draft.carbohydrate != null) 'CARBOHYDRATE',
    };
  }

  @override
  void dispose() {
    _calories.dispose();
    _protein.dispose();
    _fat.dispose();
    _carbohydrate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('OCR PREVIEW')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: DecoratedBox(
                        key: const ValueKey('nutrition-preview-source-image'),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: InteractiveViewer(
                          child: _previewImage(widget.image.dataUrl),
                        ),
                      ),
                    ),
                    AppSpacing.gapMD,
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text('OBSERVED NUTRITION'),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _metricCard(
                            'ENERGY',
                            'ENERGY',
                            _calories,
                            'kcal',
                            constraints,
                          ),
                          _metricCard(
                            'PROTEIN',
                            'PROTEIN',
                            _protein,
                            'g',
                            constraints,
                          ),
                          _metricCard('FAT', 'FAT', _fat, 'g', constraints),
                          _metricCard(
                            'CARBOHYDRATE',
                            'CARBOHYDRATE',
                            _carbohydrate,
                            'g',
                            constraints,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: AppSpacing.cardPadding,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _result()),
                      child: const Text('APPLY'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _metricCard(
    String label,
    String field,
    TextEditingController controller,
    String unit,
    BoxConstraints constraints,
  ) {
    final status = _previewStatus(field);
    final width = constraints.maxWidth >= 320
        ? (constraints.maxWidth - AppSpacing.sm) / 2
        : constraints.maxWidth;
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label)),
                  _OcrStatusChip(status: status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                key: ValueKey('nutrition-preview-$field'),
                controller: controller,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: Theme.of(context).textTheme.titleMedium,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: unit,
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _OcrPreviewStatus _previewStatus(String field) {
    if (widget.reviewFields.contains(field)) return _OcrPreviewStatus.check;
    if (!_observedFields.contains(field)) return _OcrPreviewStatus.manual;
    return _OcrPreviewStatus.verified;
  }

  NutritionOcrDraft _result() => NutritionOcrDraft(
    basisQuantity: widget.draft.basisQuantity,
    basisUnit: widget.draft.basisUnit,
    calories: _numberValue(_calories.text),
    protein: _numberValue(_protein.text),
    fat: _numberValue(_fat.text),
    carbohydrate: _numberValue(_carbohydrate.text),
    packageQuantity: widget.draft.packageQuantity,
    packageUnit: widget.draft.packageUnit,
  );
}

enum _OcrPreviewStatus { verified, check, manual }

class _OcrStatusChip extends StatelessWidget {
  const _OcrStatusChip({required this.status});
  final _OcrPreviewStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      _OcrPreviewStatus.verified => ('VERIFIED', colors.primary),
      _OcrPreviewStatus.check => ('CHECK', colors.tertiary),
      _OcrPreviewStatus.manual => ('MANUAL', colors.outline),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

TextEditingController _numberController(double? value) => TextEditingController(
  text: value == null ? '' : FoodNutritionFormatter.amount(value),
);

double? _numberValue(String value) {
  final parsed = double.tryParse(value.trim());
  return parsed != null && parsed.isFinite ? parsed : null;
}

Widget _previewImage(String dataUrl) {
  final separator = dataUrl.indexOf(',');
  if (separator < 0) return const Center(child: Text('IMAGE UNAVAILABLE'));
  try {
    return Image.memory(
      base64Decode(dataUrl.substring(separator + 1)),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Center(child: Text('IMAGE UNAVAILABLE')),
    );
  } on FormatException {
    return const Center(child: Text('IMAGE UNAVAILABLE'));
  }
}

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
