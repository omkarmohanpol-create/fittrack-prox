import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/measurement_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../utils/validators.dart';
import '../widgets/gradient_button.dart';

/// Body weight, body fat and tape measurements over time.
class MeasurementsScreen extends StatelessWidget {
  const MeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MeasurementProvider>();
    final metric = context.watch<SettingsProvider>().useMetric;
    final (weight, previous) = provider.latestTwo((m) => m.weightKg);
    final points = provider.series((m) => m.weightKg);

    return Scaffold(
      appBar: AppBar(title: const Text('Body measurements')),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        tooltip: 'Add measurement',
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
          children: [
            if (weight != null)
              _WeightHeader(weightKg: weight, previousKg: previous, metric: metric),
            if (points.length >= 2) ...[
              const SizedBox(height: 12),
              _WeightChart(points: points, metric: metric),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (provider.items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Text(
                  'No measurements yet.\nTap + to add your first check-in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.muted),
                ),
              )
            else
              for (final m in provider.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MeasurementCard(
                    m: m,
                    metric: metric,
                    onDelete: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final error = await provider.remove(m.id);
                      if (error != null) {
                        messenger.showSnackBar(SnackBar(content: Text(error)));
                      }
                      return error == null;
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const _AddMeasurementSheet(),
      );
}

class _WeightHeader extends StatelessWidget {
  final double weightKg;
  final double? previousKg;
  final bool metric;

  const _WeightHeader({
    required this.weightKg,
    required this.previousKg,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final change = previousKg == null ? null : weightKg - previousKg!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Latest weight',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  Formatters.weight(weightKg, metric),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (change != null)
            Text(
              '${change > 0 ? '+' : ''}${Formatters.weight(change.abs() < 0.05 ? 0 : change, metric)}'
              '\nsince last',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<(DateTime, double)> points;
  final bool metric;

  const _WeightChart({required this.points, required this.metric});

  @override
  Widget build(BuildContext context) {
    final first = points.first.$1;
    final spots = [
      for (final (date, kg) in points)
        FlSpot(
          date.difference(first).inDays.toDouble(),
          Formatters.kgToDisplay(kg, metric),
        ),
    ];
    final ys = spots.map((s) => s.y);
    final lo = ys.reduce((a, b) => a < b ? a : b);
    final hi = ys.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) < 2 ? 2.0 : (hi - lo) * 0.2;
    final labelStyle = TextStyle(fontSize: 11, color: context.muted);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: LineChart(
        LineChartData(
          minY: (lo - pad).floorToDouble(),
          maxY: (hi + pad).ceilToDouble(),
          minX: 0,
          maxX: spots.last.x == 0 ? 1 : spots.last.x,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.borderColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, meta) => v == meta.max || v == meta.min
                    ? const SizedBox.shrink()
                    : Text(Formatters.decimal(v), style: labelStyle),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: spots.last.x <= 6 ? 1 : (spots.last.x / 4).ceilToDouble(),
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d MMM').format(first.add(Duration(days: v.round()))),
                    style: labelStyle,
                  ),
                ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  final BodyMeasurement m;
  final bool metric;
  final Future<bool> Function() onDelete;

  const _MeasurementCard({
    required this.m,
    required this.metric,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (m.weightKg != null) Formatters.weight(m.weightKg!, metric),
      if (m.bodyFatPct != null) '${Formatters.decimal(m.bodyFatPct!)}% fat',
      if (m.waistCm != null) 'waist ${Formatters.length(m.waistCm!, metric)}',
      if (m.chestCm != null) 'chest ${Formatters.length(m.chestCm!, metric)}',
      if (m.armCm != null) 'arm ${Formatters.length(m.armCm!, metric)}',
      if (m.hipsCm != null) 'hips ${Formatters.length(m.hipsCm!, metric)}',
    ];
    return Dismissible(
      key: ValueKey(m.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Formatters.relativeDay(m.date),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(parts.join('  ·  '),
                style: TextStyle(fontSize: 13, color: context.muted)),
            if (m.notes != null) ...[
              const SizedBox(height: 4),
              Text(m.notes!, style: TextStyle(fontSize: 13, color: context.faint)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddMeasurementSheet extends StatefulWidget {
  const _AddMeasurementSheet();

  @override
  State<_AddMeasurementSheet> createState() => _AddMeasurementSheetState();
}

class _AddMeasurementSheetState extends State<_AddMeasurementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _fat = TextEditingController();
  final _waist = TextEditingController();
  final _chest = TextEditingController();
  final _arm = TextEditingController();
  final _hips = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = Formatters.dateOnly(DateTime.now());
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_weight, _fat, _waist, _chest, _arm, _hips, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _value(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return v == null || v <= 0 ? null : v;
  }

  String? _percent(String? v) {
    final error = Validators.optionalNumber(v);
    if (error != null) return error;
    final n = double.tryParse((v ?? '').trim());
    if (n != null && n > 100) return 'At most 100';
    return null;
  }

  Future<void> _pickDate() async {
    final today = Formatters.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: AppConstants.maxBackdateDays)),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final metric = context.read<SettingsProvider>().useMetric;
    double? cm(TextEditingController c) {
      final v = _value(c);
      return v == null ? null : Formatters.displayToCm(v, metric);
    }

    final weight = _value(_weight);
    final m = BodyMeasurement(
      id: newUuid(),
      date: _date,
      weightKg: weight == null ? null : Formatters.displayToKg(weight, metric),
      bodyFatPct: _value(_fat),
      waistCm: cm(_waist),
      chestCm: cm(_chest),
      armCm: cm(_arm),
      hipsCm: cm(_hips),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final error = await context.read<MeasurementProvider>().add(m);
    if (!mounted) return;
    if (error != null) {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Measurement saved')));
  }

  @override
  Widget build(BuildContext context) {
    final metric = context.watch<SettingsProvider>().useMetric;
    final len = metric ? 'cm' : 'in';
    Widget field(TextEditingController c, String label,
            {String? Function(String?)? validator}) =>
        TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          validator: validator ?? Validators.optionalNumber,
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text('Add measurement',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                child: Text(Formatters.relativeDay(_date)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: field(_weight, 'Weight (${metric ? 'kg' : 'lb'})')),
              const SizedBox(width: 12),
              Expanded(child: field(_fat, 'Body fat (%)', validator: _percent)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: field(_waist, 'Waist ($len)')),
              const SizedBox(width: 12),
              Expanded(child: field(_chest, 'Chest ($len)')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: field(_arm, 'Arm ($len)')),
              const SizedBox(width: 12),
              Expanded(child: field(_hips, 'Hips ($len)')),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Save',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
