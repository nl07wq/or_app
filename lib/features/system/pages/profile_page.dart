import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../data/profile_nationalities.dart';
import '../models/profile_model.dart';
import '../repository/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.repository});

  final ProfileRepository? repository;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _height = TextEditingController();
  late final ProfileRepository _repository;
  String? _gender;
  String? _nationality;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AppRepositoryRegistry.container.profile;
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _repository.findCurrent();
      if (!mounted) return;
      _name.text = profile?.userName ?? '';
      _height.text = profile?.heightCm == null
          ? ''
          : _formatHeight(profile!.heightCm!);
      setState(() {
        _gender = profile?.gender;
        _nationality = profile?.nationality;
        _loading = false;
        _dirty = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'プロフィールを読み込めませんでした';
      });
    }
  }

  void _changed() => setState(() {
    _dirty = true;
    _message = null;
  });

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final profile = ProfileModel.validated(
        userName: _name.text,
        heightCm: _height.text.trim().isEmpty
            ? null
            : double.parse(_height.text.trim()),
        gender: _gender,
        nationality: _nationality,
      );
      final stored = await _repository.save(profile);
      if (!mounted) return;
      _name.text = stored.userName ?? '';
      _height.text = stored.heightCm == null
          ? ''
          : _formatHeight(stored.heightCm!);
      setState(() {
        _gender = stored.gender;
        _nationality = stored.nationality;
        _dirty = false;
        _message = 'プロフィールを保存しました';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'プロフィールを保存できませんでした');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateHeight(String? source) {
    final value = source?.trim() ?? '';
    if (value.isEmpty) return null;
    if (!RegExp(r'^\d+(?:\.\d)?$').hasMatch(value)) {
      return '身長は小数点第一位まで入力してください。';
    }
    if ((double.tryParse(value) ?? 0) <= 0) {
      return '身長は0より大きい値を入力してください。';
    }
    return null;
  }

  Future<void> _selectNationality() async {
    final selection = await showModalBottomSheet<_NationalitySelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NationalityPicker(selected: _nationality),
    );
    if (!mounted || selection == null || selection.value == _nationality) {
      return;
    }
    setState(() {
      _nationality = selection.value;
      _dirty = true;
      _message = null;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PROFILE')),
    body: _loading
        ? const Center(child: Text('取得中です'))
        : Form(
            key: _formKey,
            child: ListView(
              key: const ValueKey('profile-content'),
              padding: AppSpacing.cardPadding,
              children: [
                const SectionHeader(
                  icon: Icons.person_outline,
                  title: 'PROFILE',
                ),
                AppSpacing.gapSM,
                OperationCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const ValueKey('profile-user-name'),
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'User Name',
                          hintText: '未設定',
                        ),
                        onChanged: (_) => _changed(),
                      ),
                      AppSpacing.gapMD,
                      TextFormField(
                        key: const ValueKey('profile-height'),
                        controller: _height,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Height',
                          suffixText: 'cm',
                          hintText: '未設定',
                        ),
                        validator: _validateHeight,
                        onChanged: (_) => _changed(),
                      ),
                      AppSpacing.gapMD,
                      DropdownButtonFormField<String>(
                        key: const ValueKey('profile-gender'),
                        initialValue: _gender,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          suffixIcon: _gender == null
                              ? null
                              : IconButton(
                                  tooltip: '選択を解除',
                                  onPressed: () {
                                    _gender = null;
                                    _changed();
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                        hint: const Text('未設定'),
                        items: const [
                          DropdownMenuItem(
                            value: ProfileGender.male,
                            child: Text('男性'),
                          ),
                          DropdownMenuItem(
                            value: ProfileGender.female,
                            child: Text('女性'),
                          ),
                          DropdownMenuItem(
                            value: ProfileGender.preferNotToSay,
                            child: Text('回答しない'),
                          ),
                        ],
                        onChanged: (value) {
                          _gender = value;
                          _changed();
                        },
                      ),
                      AppSpacing.gapMD,
                      ListTile(
                        key: const ValueKey('profile-nationality'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Nationality'),
                        subtitle: Text(_nationality ?? '未設定'),
                        trailing: const Icon(Icons.search),
                        onTap: _selectNationality,
                      ),
                      AppSpacing.gapMD,
                      FilledButton.icon(
                        key: const ValueKey('save-profile'),
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('プロフィールを保存'),
                      ),
                      AppSpacing.gapSM,
                      Text(_dirty ? '未保存の変更があります' : '保存済み'),
                      if (_message != null) ...[
                        AppSpacing.gapSM,
                        Text(_message!, key: const ValueKey('profile-message')),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
  );

  static String _formatHeight(double value) => value == value.truncateToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class _NationalityPicker extends StatefulWidget {
  const _NationalityPicker({required this.selected});

  final String? selected;

  @override
  State<_NationalityPicker> createState() => _NationalityPickerState();
}

class _NationalityPickerState extends State<_NationalityPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = ProfileNationalities.values
        .where((value) => value.contains(_query.trim()))
        .toList(growable: false);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              TextField(
                key: const ValueKey('nationality-search'),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '国・地域を検索',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              AppSpacing.gapSM,
              ListTile(
                title: const Text('未選択'),
                leading: const Icon(Icons.remove_circle_outline),
                onTap: () =>
                    Navigator.pop(context, const _NationalitySelection(null)),
              ),
              const Divider(),
              Expanded(
                child: results.isEmpty
                    ? const Center(child: Text('該当する国・地域がありません'))
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final value = results[index];
                          return ListTile(
                            title: Text(value),
                            trailing: value == widget.selected
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => Navigator.pop(
                              context,
                              _NationalitySelection(value),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NationalitySelection {
  const _NationalitySelection(this.value);

  final String? value;
}
