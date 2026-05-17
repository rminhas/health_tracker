import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/profile_provider.dart';
import '../services/export_service.dart';

enum _RangePreset { today, last7, last30, allTime, custom }

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  _RangePreset _preset = _RangePreset.last7;
  DateTime _customStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEnd = DateTime.now();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export data')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Export your daily health data as two CSV files (a daily '
              'summary and a per-entry detail file). Open them in any '
              'spreadsheet app.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text('Date range', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            RadioGroup<_RangePreset>(
              groupValue: _preset,
              onChanged: (v) => setState(() => _preset = v ?? _preset),
              child: Column(
                children: [
                  _rangeTile(_RangePreset.today, 'Today'),
                  _rangeTile(_RangePreset.last7, 'Last 7 days'),
                  _rangeTile(_RangePreset.last30, 'Last 30 days'),
                  _rangeTile(_RangePreset.allTime, 'All time'),
                  _rangeTile(_RangePreset.custom, 'Custom range…'),
                ],
              ),
            ),
            if (_preset == _RangePreset.custom) _buildCustomPicker(),
            const Spacer(),
            FilledButton.icon(
              onPressed: _exporting ? null : _doExport,
              icon: _exporting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share),
              label: Text(_exporting ? 'Preparing…' : 'Export & share'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeTile(_RangePreset value, String label) {
    return RadioListTile<_RangePreset>(
      title: Text(label),
      value: value,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildCustomPicker() {
    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickCustom(isStart: true),
              child: Text('From: ${_fmt(_customStart)}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickCustom(isStart: false),
              child: Text('To: ${_fmt(_customEnd)}'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustom({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? _customStart : _customEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _customStart = picked;
        if (_customEnd.isBefore(_customStart)) _customEnd = _customStart;
      } else {
        _customEnd = picked;
        if (_customStart.isAfter(_customEnd)) _customStart = _customEnd;
      }
    });
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  ({DateTime start, DateTime end}) _resolveRange() {
    final today = DateTime.now();
    switch (_preset) {
      case _RangePreset.today:
        return (start: today, end: today);
      case _RangePreset.last7:
        return (start: today.subtract(const Duration(days: 6)), end: today);
      case _RangePreset.last30:
        return (start: today.subtract(const Duration(days: 29)), end: today);
      case _RangePreset.allTime:
        // 5-year cap keeps "All time" bounded for the per-day health queries.
        return (start: today.subtract(const Duration(days: 365 * 5)), end: today);
      case _RangePreset.custom:
        return (start: _customStart, end: _customEnd);
    }
  }

  Future<void> _doExport() async {
    setState(() => _exporting = true);
    final profileProvider = context.read<ProfileProvider>();
    final range = _resolveRange();

    try {
      final result = await ExportService().exportRange(
        start: range.start,
        end: range.end,
        profile: profileProvider.profile,
        goal: profileProvider.goal,
        weightUnit: profileProvider.weightUnit,
      );

      if (!mounted) return;
      await Share.shareXFiles(
        [
          XFile(result.summaryFile.path),
          XFile(result.detailFile.path),
        ],
        subject: 'Health Tracker export (${result.daysCovered} days)',
        text:
            'Daily summary and detailed entries for ${result.daysCovered} days '
            'from Health Tracker.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
