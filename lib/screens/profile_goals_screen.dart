import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../models/goal.dart';
import '../models/weight_unit.dart';
import '../providers/profile_provider.dart';

class ProfileGoalsScreen extends StatefulWidget {
  const ProfileGoalsScreen({super.key});

  @override
  State<ProfileGoalsScreen> createState() => _ProfileGoalsScreenState();
}

class _ProfileGoalsScreenState extends State<ProfileGoalsScreen> {
  final _formKey = GlobalKey<FormState>();

  late int _age;
  late double _heightCm;
  late String _biologicalSex;
  late String _activityLevel;
  late WeightUnit _displayUnit;

  late TextEditingController _currentWeightCtrl;
  late TextEditingController _targetWeightCtrl;
  late TextEditingController _weeklyRateCtrl;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProfileProvider>();
    _age = provider.profile?.age ?? 30;
    _heightCm = provider.profile?.heightCm ?? 170.0;
    _biologicalSex = provider.profile?.biologicalSex ?? 'Male';
    _activityLevel = provider.profile?.activityLevel ?? 'Moderately Active';
    _displayUnit = provider.weightUnit;

    final currentKg = provider.latestWeightLog?.weight ?? 75.0;
    final targetKg = provider.goal?.targetWeightKg ?? 70.0;
    final rateKg = provider.goal?.weeklyChangeRateKg ?? -0.5;

    _currentWeightCtrl = TextEditingController(
        text: _displayUnit.toDisplay(currentKg).toStringAsFixed(1));
    _targetWeightCtrl = TextEditingController(
        text: _displayUnit.toDisplay(targetKg).toStringAsFixed(1));
    _weeklyRateCtrl = TextEditingController(
        text: _displayUnit.toDisplay(rateKg).toStringAsFixed(1));
  }

  @override
  void dispose() {
    _currentWeightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _weeklyRateCtrl.dispose();
    super.dispose();
  }

  void _onUnitChanged(Set<WeightUnit> selection) {
    final newUnit = selection.first;
    if (newUnit == _displayUnit) return;

    final currentKg = _displayUnit.toKg(double.tryParse(_currentWeightCtrl.text) ?? 0);
    final targetKg = _displayUnit.toKg(double.tryParse(_targetWeightCtrl.text) ?? 0);
    final rateKg = _displayUnit.toKg(double.tryParse(_weeklyRateCtrl.text) ?? 0);

    setState(() {
      _displayUnit = newUnit;
      _currentWeightCtrl.text = newUnit.toDisplay(currentKg).toStringAsFixed(1);
      _targetWeightCtrl.text = newUnit.toDisplay(targetKg).toStringAsFixed(1);
      _weeklyRateCtrl.text = newUnit.toDisplay(rateKg).toStringAsFixed(1);
    });

    context.read<ProfileProvider>().setWeightUnit(newUnit);
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final provider = context.read<ProfileProvider>();

      provider.saveProfile(UserProfile(
        age: _age,
        heightCm: _heightCm,
        biologicalSex: _biologicalSex,
        activityLevel: _activityLevel,
      ));

      final currentWeightKg =
          _displayUnit.toKg(double.tryParse(_currentWeightCtrl.text) ?? 0);
      final targetWeightKg =
          _displayUnit.toKg(double.tryParse(_targetWeightCtrl.text) ?? 0);
      final weeklyRateKg =
          _displayUnit.toKg(double.tryParse(_weeklyRateCtrl.text) ?? 0);

      provider.saveGoal(Goal(
        targetWeightKg: targetWeightKg,
        weeklyChangeRateKg: weeklyRateKg,
      ));

      if (provider.latestWeightLog == null ||
          provider.latestWeightLog!.weight != currentWeightKg) {
        provider.logWeight(currentWeightKg);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile and Goals saved!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Goals')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Physical Attributes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _age.toString(),
                decoration: const InputDecoration(
                    labelText: 'Age (years)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
                onSaved: (v) => _age = int.parse(v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _heightCm.toString(),
                decoration: const InputDecoration(
                    labelText: 'Height (cm)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
                onSaved: (v) => _heightCm = double.parse(v!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Weight unit:'),
                  const SizedBox(width: 16),
                  SegmentedButton<WeightUnit>(
                    segments: const [
                      ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                      ButtonSegment(value: WeightUnit.lbs, label: Text('lbs')),
                    ],
                    selected: {_displayUnit},
                    onSelectionChanged: _onUnitChanged,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentWeightCtrl,
                decoration: InputDecoration(
                    labelText: 'Current Weight (${_displayUnit.label})',
                    border: const OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    (double.tryParse(v ?? '') == null) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _biologicalSex,
                decoration: const InputDecoration(
                    labelText: 'Biological Sex',
                    border: OutlineInputBorder()),
                items: ['Male', 'Female']
                    .map((v) =>
                        DropdownMenuItem<String>(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _biologicalSex = v!),
                onSaved: (v) => _biologicalSex = v!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _activityLevel,
                decoration: const InputDecoration(
                    labelText: 'Activity Level',
                    border: OutlineInputBorder()),
                items: [
                  'Sedentary',
                  'Lightly Active',
                  'Moderately Active',
                  'Very Active',
                  'Super Active'
                ]
                    .map((v) =>
                        DropdownMenuItem<String>(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _activityLevel = v!),
                onSaved: (v) => _activityLevel = v!,
              ),
              const SizedBox(height: 32),
              const Text('Goals',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetWeightCtrl,
                decoration: InputDecoration(
                    labelText: 'Target Weight (${_displayUnit.label})',
                    border: const OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    (double.tryParse(v ?? '') == null) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weeklyRateCtrl,
                decoration: InputDecoration(
                    labelText: 'Weekly Change Rate (${_displayUnit.rateLabel})',
                    helperText: 'Negative for loss, positive for gain',
                    border: const OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(
                    signed: true, decimal: true),
                validator: (v) =>
                    (double.tryParse(v ?? '') == null) ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Save Profile & Goals'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
