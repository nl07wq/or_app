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
}) async {
  final choice = await _chooseScanMode(
    context,
    diagnosticsAvailable: gateway is FoodOcrDiagnosticGateway,
  );
  if (choice == null || !context.mounted) return null;
  if (choice == _NutritionScanChoice.diagnostics) {
    await _showNutritionOcrDiagnostics(context, gateway);
    return null;
  }
  final scanMode = switch (choice) {
    _NutritionScanChoice.standard => FoodOcrScanMode.standard,
    _NutritionScanChoice.reader => FoodOcrScanMode.nutritionLabelReader,
    _NutritionScanChoice.diagnostics => throw StateError(
      'Diagnostics is not a scan mode.',
    ),
  };

  while (context.mounted) {
    if (!context.mounted) return null;
    final capture = await _captureNutrition(
      context: context,
      gateway: gateway,
      scanMode: scanMode,
    );
    if (capture == null || !context.mounted) return null;
    final parsed = capture.draft?.isEmpty == false
        ? (
            draft: capture.draft!,
            conflicts: capture.conflicts,
            decisions: capture.decisions,
          )
        : _nutritionDraft(capture.rawText);
    if (parsed.draft.isEmpty) return null;
    final action = await _reviewNutrition(
      context,
      parsed.draft,
      parsed.conflicts,
      parsed.decisions,
      scanMode,
    );
    if (action == _NutritionReviewAction.rescan) continue;
    if (action != _NutritionReviewAction.apply) return null;
    return FoodNutritionOcrResult(
      capture.rawText,
      parsed.draft,
      scanMode: scanMode,
    );
  }
  return null;
}

Future<
  ({
    String rawText,
    NutritionOcrDraft? draft,
    Set<String> conflicts,
    Map<String, Map<String, dynamic>> decisions,
  })?
>
_captureNutrition({
  required BuildContext context,
  required FoodInputCaptureGateway gateway,
  required FoodOcrScanMode scanMode,
}) async {
  if (gateway case final FoodLiveCaptureGateway liveGateway) {
    final session = FoodNutritionCandidateSession();
    final rawText = await liveGateway.recognizeTextLive(
      title: 'NUTRITION LABEL SCAN',
      instruction: '栄養成分表示を枠内に入れてください',
      describeCandidate: session.describe,
      engine: FoodOcrEngine.tesseract,
      scanMode: scanMode,
    );
    if (rawText == null) return null;
    for (final pass in _ocrPasses(rawText)) {
      session.describe(pass);
    }
    return (
      rawText: rawText,
      draft: session.draft,
      conflicts: session.conflicts,
      decisions: session.fieldDecisions,
    );
  }

  final source = await _chooseStillImageSource(context);
  if (source == null) return null;
  final image = await gateway.selectImage(source);
  if (image == null) return null;
  final rawText = await gateway.recognizeJapaneseText(
    image,
    mode: FoodTextOcrMode.nutrition,
    engine: FoodOcrEngine.tesseract,
    scanMode: scanMode,
  );
  return (
    rawText: rawText,
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

enum _NutritionScanChoice { standard, reader, diagnostics }

Future<_NutritionScanChoice?> _chooseScanMode(
  BuildContext context, {
  required bool diagnosticsAvailable,
}) => showModalBottomSheet<_NutritionScanChoice>(
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
          child: Text('SELECT SCAN MODE'),
        ),
        ListTile(
          key: const ValueKey('nutrition-mode-standard'),
          leading: const Icon(Icons.document_scanner_outlined),
          title: const Text('STANDARD OCR'),
          subtitle: const Text('従来方式'),
          onTap: () => Navigator.pop(context, _NutritionScanChoice.standard),
        ),
        ListTile(
          key: const ValueKey('nutrition-mode-reader'),
          leading: const Icon(Icons.document_scanner_outlined),
          title: const Text('NUTRITION LABEL READER'),
          subtitle: const Text('栄養表示専用'),
          onTap: () => Navigator.pop(context, _NutritionScanChoice.reader),
        ),
        if (diagnosticsAvailable)
          ListTile(
            key: const ValueKey('nutrition-ocr-diagnostics'),
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('OCR DIAGNOSTICS'),
            subtitle: const Text('一時監査：同一画像で両モードを比較'),
            onTap: () =>
                Navigator.pop(context, _NutritionScanChoice.diagnostics),
          ),
      ],
    ),
  ),
);

Future<void> _showNutritionOcrDiagnostics(
  BuildContext context,
  FoodInputCaptureGateway gateway,
) async {
  final FoodOcrDiagnosticGateway? diagnosticGateway =
      gateway is FoodOcrDiagnosticGateway
      ? gateway as FoodOcrDiagnosticGateway
      : null;
  if (diagnosticGateway == null) return;
  final source = await _chooseStillImageSource(context);
  if (source == null || !context.mounted) return;
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
  Map<String, Map<String, dynamic>> decisions,
  FoodOcrScanMode scanMode,
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
              _value('SCAN MODE', scanMode.label),
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
              for (final entry in decisions.entries)
                _value(
                  '${entry.key} OCR',
                  '${entry.value['confidence'] ?? 'NONE'} / '
                      '${entry.value['decision'] ?? 'NOT_AVAILABLE'}'
                      '${_reviewEvidence(entry.value)}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _NutritionReviewAction.cancel),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _NutritionReviewAction.rescan),
            child: const Text('RESCAN'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _NutritionReviewAction.apply),
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

String _reviewEvidence(Map<String, dynamic> decision) {
  final value = decision['value'];
  if (value is! num) return '';
  final unit = decision['unit'];
  return ' / candidate: $value (${unit is String ? unit : 'UNIT NOT AVAILABLE'})';
}

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
