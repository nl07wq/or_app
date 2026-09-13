import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../training/services/training_history_domain_service.dart';
import '../../training/widgets/body_map_svg_prototype.dart';
import '../services/body_map_geometry_tuner.dart';

class BodyMapSvgPreviewPage extends StatefulWidget {
  const BodyMapSvgPreviewPage({super.key});

  @override
  State<BodyMapSvgPreviewPage> createState() => _BodyMapSvgPreviewPageState();
}

class _BodyMapSvgPreviewPageState extends State<BodyMapSvgPreviewPage> {
  // This is a geometry identity, intentionally independent of the app release
  // SHA. Export-only deployments must not hide a valid local tuner draft.
  // This geometry identity changes only when canonical preview SVG geometry is
  // baked. It makes pre-bake tuner drafts stale rather than double-applying
  // them to their own baked result.
  static const _baselineCommit = 'body-map-svg-v1-final-geometry-58bf285';

  final _tuner = BodyMapGeometryTunerController(
    baselineCommit: _baselineCommit,
  );
  final Map<String, Rect> _baseBounds = {};
  SvgBodyMapSide side = SvgBodyMapSide.front;
  MuscleGroup? selected;
  String? _selectedRegionId;
  bool support = false;
  bool _editMode = false;
  bool _showTuned = true;
  bool _fineAdjustments = false;
  int _activeComponentIndex = 0;
  RecoveryStatus? recoveryStatus;

  @override
  void initState() {
    super.initState();
    _tuner.addListener(_onTunerChanged);
    _tuner.load();
  }

  void _onTunerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tuner
      ..removeListener(_onTunerChanged)
      ..dispose();
    super.dispose();
  }

  String get _sideName => side.name;

  Path _pathOverride(String id, Path basePath) {
    final key = BodyMapGeometryTunerController.keyFor(_sideName, id);
    _baseBounds[key] = basePath.getBounds();
    return _tuner.pathFor(
      side: _sideName,
      regionId: id,
      basePath: basePath,
      locked: id == 'front-core',
    );
  }

  BodyMapGeometryDraft? get _selectedDraft => _selectedRegionId == null
      ? null
      : _tuner.draftFor(_sideName, _selectedRegionId!);

  void _updateDraft(
    BodyMapGeometryDraft Function(BodyMapGeometryDraft) change,
  ) {
    final draft = _selectedDraft;
    if (draft == null || draft.locked) return;
    _tuner.update(change(draft));
  }

  void _updateComponent(BodyMapGeometryComponent component) {
    if (_selectedRegionId == null) return;
    _tuner.updateComponent(
      _sideName,
      _selectedRegionId!,
      _activeComponentIndex,
      component,
    );
  }

  Future<void> _showAddShape(BodyMapGeometryDraft draft) async {
    final shape = await showModalBottomSheet<BodyMapGeometryShape>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in BodyMapGeometryShape.values.where(
              (item) => item != BodyMapGeometryShape.current,
            ))
              ListTile(
                title: Text(item.label),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (shape != null &&
        _tuner.addComponent(_sideName, draft.regionId, shape)) {
      setState(() => _activeComponentIndex = draft.effectiveComponents.length);
    }
  }

  Future<void> _copy(String content, String label) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied to clipboard.')));
  }

  Future<void> _confirmResetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RESET ALL TUNER CHANGES?'),
        content: const Text(
          'This clears only the locally saved geometry draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET ALL'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _tuner.resetAll();
      setState(() => _selectedRegionId = null);
    }
  }

  Future<void> _confirmRestoreRecoveryDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RESTORE PRODUCT OWNER RECOVERY DRAFT?'),
        content: Text(
          'This restores ${_tuner.recoveryFixtureFrontCount} FRONT and '
          '${_tuner.recoveryFixtureBackCount} BACK regions, including one '
          'two-component TRAPEZIUS. Existing valid drafts are not overwritten '
          'automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESTORE DRAFT'),
          ),
        ],
      ),
    );
    if (confirmed == true && _tuner.restoreProductOwnerRecoveryDraft()) {
      setState(() {
        _showTuned = true;
        _selectedRegionId = null;
      });
    }
  }

  Future<void> _confirmRestoreBackupDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RESTORE PREVIOUS TUNER BACKUP?'),
        content: const Text(
          'This replaces the unavailable current draft with the last valid '
          'local backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESTORE BACKUP'),
          ),
        ],
      ),
    );
    if (confirmed == true && _tuner.restoreBackupDraft()) {
      setState(() {
        _showTuned = true;
        _selectedRegionId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BODY MAP SVG PREVIEW')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<SvgBodyMapSide>(
                segments: const [
                  ButtonSegment(value: SvgBodyMapSide.front, label: Text('前面')),
                  ButtonSegment(value: SvgBodyMapSide.back, label: Text('背面')),
                ],
                selected: {side},
                onSelectionChanged: (value) {
                  if (value.isEmpty || value.first == side) return;
                  setState(() {
                    side = value.first;
                    selected = null;
                    _selectedRegionId = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_editMode) ...[
                const _EditModeBadge(),
                const SizedBox(height: 8),
                if (_tuner.hasStaleDraft) ...[
                  _StaleDraftWarning(
                    draftBaseline: _tuner.staleBaselineCommit ?? 'UNKNOWN',
                    currentBaseline: _baselineCommit,
                    onCopy: () =>
                        _copy(_tuner.copyStaleDraft(), 'Stale draft feedback'),
                    onReset: _confirmResetAll,
                  ),
                  const SizedBox(height: 8),
                ],
                if (_tuner.canRestoreProductOwnerRecovery) ...[
                  _RecoveryDraftAction(
                    onRestore: _confirmRestoreRecoveryDraft,
                    onRestoreBackup: _tuner.canRestoreBackup
                        ? _confirmRestoreBackupDraft
                        : null,
                    loadError: _tuner.loadError,
                  ),
                  const SizedBox(height: 8),
                ],
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('BASELINE')),
                    ButtonSegment(value: true, label: Text('TUNED')),
                  ],
                  selected: {_showTuned},
                  onSelectionChanged: (value) =>
                      setState(() => _showTuned = value.first),
                ),
                const SizedBox(height: 8),
              ],
              SvgBodyMapPrototype(
                side: side,
                recoveryByMuscle: const {},
                previewStatuses: recoveryStatus == null
                    ? const {}
                    : {MuscleGroup.shoulders: recoveryStatus!},
                supportMuscles: support ? {MuscleGroup.shoulders} : const {},
                selectedMuscle: _editMode ? null : selected,
                onSelected: (muscle) => setState(() => selected = muscle),
                editMode: _editMode,
                selectedRegionId: _selectedRegionId,
                onRegionSelected: (id) => setState(() {
                  _selectedRegionId = id;
                  _activeComponentIndex = 0;
                }),
                pathOverride: _editMode && _showTuned ? _pathOverride : null,
              ),
              const SizedBox(height: 12),
              if (_editMode)
                _buildTunerPanel(context)
              else ...[
                Text(
                  selected == null
                      ? 'TAP A MUSCLE REGION'
                      : 'SELECTED: ${selected!.name.toUpperCase()}',
                ),
                SwitchListTile(
                  title: const Text('SUPPORT OUTLINE PREVIEW'),
                  value: support,
                  onChanged: (value) => setState(() => support = value),
                ),
                DropdownButtonFormField<RecoveryStatus>(
                  key: ValueKey(
                    'body-map-recovery-fixture-${recoveryStatus?.name ?? 'neutral'}',
                  ),
                  initialValue: recoveryStatus,
                  decoration: const InputDecoration(
                    labelText: 'RECOVERY FILL PREVIEW',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: RecoveryStatus.recovering,
                      child: Text('回復中'),
                    ),
                    DropdownMenuItem(
                      value: RecoveryStatus.nearReady,
                      child: Text('回復目安に接近'),
                    ),
                    DropdownMenuItem(
                      value: RecoveryStatus.estimatedReady,
                      child: Text('回復目安到達'),
                    ),
                  ],
                  onChanged: (value) => setState(() => recoveryStatus = value),
                ),
                TextButton(
                  onPressed: () => setState(() => recoveryStatus = null),
                  child: const Text('NEUTRAL / データなし'),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: Icon(_editMode ? Icons.close : Icons.tune),
                label: Text(_editMode ? 'EXIT EDIT GEOMETRY' : 'EDIT GEOMETRY'),
                onPressed: _tuner.isLoaded
                    ? () => setState(() {
                        _editMode = !_editMode;
                        selected = null;
                        _selectedRegionId = null;
                      })
                    : null,
              ),
              const SizedBox(height: 8),
              const Text(
                'Prototype only — production Recovery Body Map is unchanged.',
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildTunerPanel(BuildContext context) {
    final draft = _selectedDraft;
    if (draft == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tap a visible editable muscle region to tune it.'),
        ),
      );
    }
    final canEdit = !draft.locked;
    final components = draft.effectiveComponents;
    final activeIndex = _activeComponentIndex.clamp(0, components.length - 1);
    final component = components[activeIndex];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${side.name.toUpperCase()} • ${BodyMapGeometryTunerController.regionNameFor(draft.regionId)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text('SVG ID: ${draft.regionId}'),
            Text('COMPONENT ${activeIndex + 1} / ${components.length}'),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < components.length; i++)
                  ChoiceChip(
                    label: Text('${i + 1} ${components[i].shape.label}'),
                    selected: i == activeIndex,
                    onSelected: (_) =>
                        setState(() => _activeComponentIndex = i),
                  ),
                OutlinedButton.icon(
                  onPressed:
                      canEdit &&
                          components.length <
                              BodyMapGeometryTunerController.maxComponents
                      ? () => _showAddShape(draft)
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('ADD SHAPE'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<BodyMapGeometryShape>(
              initialValue: component.shape,
              decoration: const InputDecoration(labelText: 'SHAPE'),
              items: BodyMapGeometryShape.values
                  .map(
                    (shape) => DropdownMenuItem(
                      value: shape,
                      child: Text(shape.label),
                    ),
                  )
                  .toList(),
              onChanged: canEdit
                  ? (shape) =>
                        _updateComponent(component.copyWith(shape: shape!))
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('FINE ADJUSTMENT'),
              subtitle: Text(
                _fineAdjustments ? '0.5 px / 1° / 0.01' : '2 px / 5° / 0.05',
              ),
              value: _fineAdjustments,
              onChanged: (value) => setState(() => _fineAdjustments = value),
            ),
            _controlRow(
              'X',
              component.x,
              _fineAdjustments ? .5 : 2,
              (delta) =>
                  _updateComponent(component.copyWith(x: component.x + delta)),
              canEdit,
            ),
            _controlRow(
              'Y',
              component.y,
              _fineAdjustments ? .5 : 2,
              (delta) =>
                  _updateComponent(component.copyWith(y: component.y + delta)),
              canEdit,
            ),
            _controlRow(
              'WIDTH',
              component.width,
              _fineAdjustments ? .5 : 2,
              (delta) => _updateComponent(
                component.copyWith(
                  width: (component.width + delta).clamp(.5, 200).toDouble(),
                ),
              ),
              canEdit,
            ),
            _controlRow(
              'HEIGHT',
              component.height,
              _fineAdjustments ? .5 : 2,
              (delta) => _updateComponent(
                component.copyWith(
                  height: (component.height + delta).clamp(.5, 340).toDouble(),
                ),
              ),
              canEdit,
            ),
            _controlRow(
              'ROTATION',
              component.rotationDeg,
              _fineAdjustments ? 1 : 5,
              (delta) => _updateComponent(
                component.copyWith(
                  rotationDeg: (component.rotationDeg + delta)
                      .clamp(-90, 90)
                      .toDouble(),
                ),
              ),
              canEdit,
              suffix: '°',
            ),
            _controlRow(
              'SCALE X',
              component.scaleX,
              _fineAdjustments ? .01 : .05,
              (delta) => _updateComponent(
                component.copyWith(
                  scaleX: (component.scaleX + delta).clamp(.1, 3).toDouble(),
                ),
              ),
              canEdit,
            ),
            _controlRow(
              'SCALE Y',
              component.scaleY,
              _fineAdjustments ? .01 : .05,
              (delta) => _updateComponent(
                component.copyWith(
                  scaleY: (component.scaleY + delta).clamp(.1, 3).toDouble(),
                ),
              ),
              canEdit,
            ),
            if (component.shape == BodyMapGeometryShape.roundedRect)
              _controlRow(
                'CORNER',
                component.cornerRadius,
                _fineAdjustments ? .5 : 2,
                (delta) => _updateComponent(
                  component.copyWith(
                    cornerRadius: (component.cornerRadius + delta)
                        .clamp(0, 100)
                        .toDouble(),
                  ),
                ),
                canEdit,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('MIRROR / LINK LEFT-RIGHT'),
              value: draft.mirrorLinked,
              onChanged: canEdit
                  ? (value) => _updateDraft(
                      (current) => current.copyWith(mirrorLinked: value),
                    )
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('LOCK REGION'),
              value: draft.locked,
              onChanged: (value) =>
                  _tuner.update(draft.copyWith(locked: value), mirror: false),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      _tuner.resetRegion(_sideName, draft.regionId),
                  child: const Text('RESET REGION'),
                ),
                OutlinedButton(
                  onPressed:
                      canEdit &&
                          components.length <
                              BodyMapGeometryTunerController.maxComponents
                      ? () {
                          if (_tuner.duplicateComponent(
                            _sideName,
                            draft.regionId,
                            activeIndex,
                          )) {
                            setState(
                              () => _activeComponentIndex = components.length,
                            );
                          }
                        }
                      : null,
                  child: const Text('DUPLICATE COMPONENT'),
                ),
                OutlinedButton(
                  onPressed: canEdit && components.length > 1
                      ? () {
                          if (_tuner.deleteComponent(
                            _sideName,
                            draft.regionId,
                            activeIndex,
                          )) {
                            setState(() => _activeComponentIndex = 0);
                          }
                        }
                      : null,
                  child: const Text('DELETE COMPONENT'),
                ),
                FilledButton.tonal(
                  onPressed: () =>
                      _copy(_tuner.copyRegion(draft), 'Region feedback'),
                  child: const Text('COPY REGION'),
                ),
                OutlinedButton(
                  onPressed: _confirmResetAll,
                  child: const Text('RESET ALL'),
                ),
                FilledButton(
                  onPressed: () => _copy(
                    _tuner.copyAllChanges(_baseBounds),
                    'All changed-region feedback',
                  ),
                  child: const Text('COPY ALL CHANGES'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlRow(
    String label,
    double value,
    double amount,
    ValueChanged<double> onAdjust,
    bool enabled, {
    String suffix = '',
  }) => Row(
    children: [
      SizedBox(width: 78, child: Text(label)),
      IconButton(
        tooltip: 'Decrease $label',
        onPressed: enabled ? () => onAdjust(-amount) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      Expanded(
        child: Text(
          '${value.toStringAsFixed(2)}$suffix',
          textAlign: TextAlign.center,
        ),
      ),
      IconButton(
        tooltip: 'Increase $label',
        onPressed: enabled ? () => onAdjust(amount) : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}

class _EditModeBadge extends StatelessWidget {
  const _EditModeBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.deepPurple.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.deepPurpleAccent),
    ),
    child: const Text(
      'EDIT MODE — local geometry draft only',
      textAlign: TextAlign.center,
    ),
  );
}

class _StaleDraftWarning extends StatelessWidget {
  const _StaleDraftWarning({
    required this.draftBaseline,
    required this.currentBaseline,
    required this.onCopy,
    required this.onReset,
  });

  final String draftBaseline;
  final String currentBaseline;
  final VoidCallback onCopy;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.amber.withValues(alpha: .12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STALE DRAFT — BASELINE MISMATCH'),
          Text('Draft: $draftBaseline'),
          Text('Current: $currentBaseline'),
          const SizedBox(height: 6),
          const Text('The old transforms are preserved but never applied.'),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: onCopy, child: const Text('COPY STALE')),
              TextButton(onPressed: onReset, child: const Text('RESET DRAFT')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _RecoveryDraftAction extends StatelessWidget {
  const _RecoveryDraftAction({
    required this.onRestore,
    this.onRestoreBackup,
    this.loadError,
  });

  final VoidCallback onRestore;
  final VoidCallback? onRestoreBackup;
  final String? loadError;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.blue.withValues(alpha: .12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PRODUCT OWNER RECOVERY DRAFT AVAILABLE'),
          const Text(
            'Restores the supplied full-body draft only after confirmation.',
          ),
          if (loadError != null) Text(loadError!),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (onRestoreBackup != null)
                OutlinedButton(
                  onPressed: onRestoreBackup,
                  child: const Text('RESTORE PREVIOUS BACKUP'),
                ),
              FilledButton.tonal(
                onPressed: onRestore,
                child: const Text('RESTORE PRODUCT OWNER RECOVERY DRAFT'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
