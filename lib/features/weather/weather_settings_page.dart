import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/widgets/section_header.dart';
import 'weather_models.dart';
import 'weather_service.dart';

class WeatherSettingsPage extends StatefulWidget {
  const WeatherSettingsPage({super.key, this.service});
  final WeatherService? service;

  @override
  State<WeatherSettingsPage> createState() => _WeatherSettingsPageState();
}

class _WeatherSettingsPageState extends State<WeatherSettingsPage> {
  late final WeatherService _service = widget.service ?? WeatherService();
  final _query = TextEditingController();
  WeatherLocationPreferences _preferences = const WeatherLocationPreferences(
    locations: [],
    activeLocationId: null,
  );
  List<WeatherGeocodingResult> _results = const [];
  bool _loading = true;
  bool _searching = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final value = await _service.loadLocations();
    if (!mounted) return;
    setState(() {
      _preferences = value;
      _loading = false;
    });
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _message = null;
      _results = const [];
    });
    try {
      final values = await _service.searchLocations(_query.text);
      if (!mounted) return;
      setState(() {
        _results = values;
        _message = values.isEmpty ? 'NO LOCATION FOUND' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _message = 'LOCATION SEARCH UNAVAILABLE');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(WeatherGeocodingResult result) async {
    try {
      await _service.addLocation(result.toLocation());
      _query.clear();
      if (!mounted) return;
      setState(() => _results = const []);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    }
  }

  Future<void> _activate(WeatherLocation location) async {
    await _service.setActiveLocation(location.stableId);
    await _load();
  }

  Future<void> _remove(WeatherLocation location) async {
    await _service.removeLocation(location.stableId);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('WEATHER LOCATIONS'), centerTitle: true),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: AppSpacing.cardPadding,
            children: [
              const SectionHeader(
                icon: Icons.public_outlined,
                title: 'WEATHER LOCATIONS',
              ),
              Text(
                '${_preferences.locations.length} / ${WeatherLocationPreferences.maximumLocations} SAVED',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              AppSpacing.gapSM,
              for (
                var index = 0;
                index < _preferences.locations.length;
                index++
              )
                _LocationRow(
                  index: index + 1,
                  location: _preferences.locations[index],
                  active:
                      _preferences.locations[index].stableId ==
                      _preferences.activeLocationId,
                  onActivate: () => _activate(_preferences.locations[index]),
                  onRemove: () => _remove(_preferences.locations[index]),
                ),
              AppSpacing.gapLG,
              const SectionHeader(
                icon: Icons.add_location_alt_outlined,
                title: 'ADD LOCATION',
              ),
              AppSpacing.gapSM,
              OperationTextField(
                controller: _query,
                label: 'CITY OR AREA',
                hint: '市原 / 千葉 / 札幌',
              ),
              AppSpacing.gapSM,
              OperationButton(
                text:
                    _preferences.locations.length >=
                        WeatherLocationPreferences.maximumLocations
                    ? 'LOCATION LIMIT REACHED'
                    : (_searching ? 'SEARCHING...' : 'SEARCH'),
                icon: Icons.travel_explore,
                onPressed:
                    _searching ||
                        _preferences.locations.length >=
                            WeatherLocationPreferences.maximumLocations
                    ? null
                    : _search,
                role: OperationActionRole.primary,
              ),
              if (_message != null) ...[
                AppSpacing.gapSM,
                Text(_message!, style: Theme.of(context).textTheme.bodySmall),
              ],
              for (final result in _results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(result.displayName),
                  subtitle: Text(result.timezone),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => _add(result),
                ),
              AppSpacing.gapLG,
              Text(
                'Open-Meteo location search. GPS is not used.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
  );
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.index,
    required this.location,
    required this.active,
    required this.onActivate,
    required this.onRemove,
  });
  final int index;
  final WeatherLocation location;
  final bool active;
  final VoidCallback onActivate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Text(index.toString().padLeft(2, '0')),
    title: Text(location.displayName),
    subtitle: Text(
      active ? 'ACTIVE · ${location.timezone}' : location.timezone,
    ),
    trailing: Wrap(
      spacing: 2,
      children: [
        IconButton(
          tooltip: 'Make active',
          onPressed: active ? null : onActivate,
          icon: Icon(
            active ? Icons.check_circle : Icons.radio_button_unchecked,
          ),
        ),
        IconButton(
          tooltip: 'Remove',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
  );
}
