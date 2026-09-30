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
  WeatherLocation? _location;
  List<WeatherGeocodingResult> _results = const [];
  bool _loading = true;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    final value = await _service.loadLocation();
    if (!mounted) return;
    setState(() {
      _location = value;
      _loading = false;
    });
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _error = null;
      _results = const [];
    });
    try {
      final values = await _service.searchLocations(_query.text);
      if (!mounted) return;
      setState(() => _results = values);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'LOCATION SEARCH UNAVAILABLE');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _select(WeatherGeocodingResult result) async {
    final location = result.toLocation();
    await _service.saveLocation(location);
    if (!mounted) return;
    setState(() {
      _location = location;
      _results = const [];
      _query.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('WEATHER LOCATION SET: ${location.displayName}')),
    );
  }

  Future<void> _remove() async {
    await _service.removeLocation();
    if (!mounted) return;
    setState(() {
      _location = null;
      _results = const [];
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('WEATHER LOCATION'), centerTitle: true),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: AppSpacing.cardPadding,
            children: [
              const SectionHeader(
                icon: Icons.public_outlined,
                title: 'WEATHER LOCATION',
              ),
              AppSpacing.gapSM,
              Text(
                _location?.displayName ?? 'LOCATION NOT SET',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_location != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${_location!.latitude.toStringAsFixed(4)}, '
                  '${_location!.longitude.toStringAsFixed(4)}  '
                  '${_location!.timezone}',
                ),
                AppSpacing.gapSM,
                OperationButton(
                  text: 'REMOVE LOCATION',
                  icon: Icons.location_off_outlined,
                  role: OperationActionRole.danger,
                  onPressed: _remove,
                ),
              ],
              AppSpacing.gapLG,
              const SectionHeader(icon: Icons.search, title: 'SEARCH LOCATION'),
              AppSpacing.gapSM,
              OperationTextField(
                controller: _query,
                label: 'CITY OR AREA',
                hint: '札幌',
                onChanged: (_) => setState(() => _error = null),
              ),
              AppSpacing.gapSM,
              OperationButton(
                text: _searching ? 'SEARCHING...' : 'SEARCH',
                icon: Icons.travel_explore,
                onPressed: _searching ? null : _search,
                role: OperationActionRole.primary,
              ),
              if (_error != null) ...[
                AppSpacing.gapMD,
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (!_searching &&
                  _results.isEmpty &&
                  _query.text.trim().isNotEmpty &&
                  _error == null) ...[
                AppSpacing.gapMD,
                const Text('NO LOCATION FOUND'),
              ],
              for (final result in _results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(result.displayName),
                  subtitle: Text(result.timezone),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _select(result),
                ),
              AppSpacing.gapLG,
              Text(
                'Location search is provided by Open-Meteo. GPS is not used.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
  );
}
