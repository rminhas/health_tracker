import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/food_log_provider.dart';
import '../services/food_data_api.dart';
import '../models/food_log.dart';
import '../models/food_unit.dart';
import '../models/meal_type.dart';
import 'barcode_scanner_screen.dart';

class FoodLoggingScreen extends StatefulWidget {
  const FoodLoggingScreen({super.key});

  @override
  State<FoodLoggingScreen> createState() => _FoodLoggingScreenState();
}

class _FoodLoggingScreenState extends State<FoodLoggingScreen> {
  final _searchController = TextEditingController();
  final _foodDataService = FoodDataService();
  List<FoodLog> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    // Rebuild on every keystroke so the empty/non-empty branch in
    // _buildResultsList() (recents vs. search results) stays in sync.
    _searchController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onTextChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      // If the field is empty, drop any stale results immediately.
      if (_searchController.text.trim().isEmpty) {
        _searchResults = [];
        _isSearching = false;
        _debounce?.cancel();
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    if (query.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchFood();
    });
  }

  Future<void> _searchFood() async {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final token = ++_searchToken;
    setState(() => _isSearching = true);

    try {
      final results = await _foodDataService.searchFood(query);
      if (!mounted || token != _searchToken) return;
      setState(() => _searchResults = results);
    } catch (e) {
      if (!mounted || token != _searchToken) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted && token == _searchToken) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _lookupBarcode(String barcode) async {
    setState(() => _isSearching = true);
    try {
      final food = await _foodDataService.lookupBarcode(barcode);
      if (!mounted) return;
      if (food == null) {
        _showBarcodeNotFound(barcode);
      } else {
        _logFood(food);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error looking up barcode: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _showBarcodeNotFound(String barcode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Text(
          'Barcode $barcode was not found in the database.\n\nTry searching by name or enter the details manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showManualEntry();
            },
            child: const Text('Enter Manually'),
          ),
        ],
      ),
    );
  }

  Future<void> _openScanner() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isDenied || status.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text(
            'Camera access is needed to scan barcodes. Please allow it in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (status.isPermanentlyDenied)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
          ],
        ),
      );
      return;
    }
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode != null && mounted) {
      await _lookupBarcode(barcode);
    }
  }

  void _showManualEntry() {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '100');
    final formKey = GlobalKey<FormState>();
    var selectedMealType = MealType.suggest();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Manual Entry'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Food name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Text('Meal', style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  _buildMealTypePicker(selectedMealType,
                      (t) => setDialogState(() => selectedMealType = t)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount (g)'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return (n == null || n <= 0) ? 'Enter a positive number' : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: calCtrl,
                    decoration: const InputDecoration(labelText: 'Calories (kcal)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter a whole number' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: proteinCtrl,
                    decoration: const InputDecoration(labelText: 'Protein (g)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: carbsCtrl,
                    decoration: const InputDecoration(labelText: 'Carbs (g)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: fatCtrl,
                    decoration: const InputDecoration(labelText: 'Fat (g)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final food = FoodLog(
                  name: nameCtrl.text.trim(),
                  calories: int.parse(calCtrl.text),
                  protein: double.parse(proteinCtrl.text),
                  carbs: double.parse(carbsCtrl.text),
                  fat: double.parse(fatCtrl.text),
                  amount: double.parse(amountCtrl.text),
                  date: DateTime.now(),
                  mealType: selectedMealType,
                );
                final provider = context.read<FoodLogProvider>();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(dialogContext);
                Navigator.pop(context);
                provider.addLog(food);
                messenger.showSnackBar(
                  SnackBar(content: Text('Logged ${food.name}')),
                );
              },
              child: const Text('Log Food'),
            ),
          ],
        ),
      ),
    );
  }

  void _logFood(FoodLog food) {
    final amountCtrl = TextEditingController(text: '100');
    var selectedUnit = FoodUnit.g;
    var selectedMealType = food.mealType ?? MealType.suggest();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final amt = double.tryParse(amountCtrl.text) ?? 0.0;
          final valid = amt > 0;
          final gramsEquivalent = amt * selectedUnit.toGrams;
          final ratio = valid ? gramsEquivalent / 100.0 : 0.0;

          return AlertDialog(
            title: Text('Add ${food.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Per 100g: ${food.calories} kcal  ·  P ${food.protein.toStringAsFixed(1)}g  ·  C ${food.carbs.toStringAsFixed(1)}g  ·  F ${food.fat.toStringAsFixed(1)}g',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text('Meal', style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  _buildMealTypePicker(selectedMealType,
                      (t) => setDialogState(() => selectedMealType = t)),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,
                          decoration: InputDecoration(
                            labelText: 'Amount (${selectedUnit.label})',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<FoodUnit>(
                        value: selectedUnit,
                        underline: const SizedBox(),
                        items: FoodUnit.values
                            .map((u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u.label),
                                ))
                            .toList(),
                        onChanged: (u) {
                          if (u != null) setDialogState(() => selectedUnit = u);
                        },
                      ),
                    ],
                  ),
                  if (selectedUnit.isVolume) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Volume units assume density ≈ 1 g/ml (accurate for liquids).',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (valid)
                    Text(
                      'At ${amt.toStringAsFixed(0)} ${selectedUnit.label}: ${(food.calories * ratio).round()} kcal  ·  P ${(food.protein * ratio).toStringAsFixed(1)}g  ·  C ${(food.carbs * ratio).toStringAsFixed(1)}g  ·  F ${(food.fat * ratio).toStringAsFixed(1)}g',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: valid
                    ? () {
                        final adjustedFood = food.copyWith(
                          amount: gramsEquivalent,
                          calories: (food.calories * ratio).round(),
                          protein: food.protein * ratio,
                          carbs: food.carbs * ratio,
                          fat: food.fat * ratio,
                          mealType: selectedMealType,
                        );
                        final provider = context.read<FoodLogProvider>();
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(dialogContext);
                        Navigator.pop(context);
                        provider.addLog(adjustedFood);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Logged ${adjustedFood.name}')),
                        );
                      }
                    : null,
                child: const Text('Log Food'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(amountCtrl.dispose);
  }

  Widget _buildMealTypePicker(MealType selected, ValueChanged<MealType> onChanged) {
    return Wrap(
      spacing: 8,
      children: MealType.values
          .map((t) => ChoiceChip(
                label: Text(t.label),
                selected: selected == t,
                onSelected: (_) => onChanged(t),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Food'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Manual entry',
            onPressed: _showManualEntry,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for food (e.g., Apple)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _isSearching ? null : _openScanner,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _searchFood(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchFood,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          if (_isSearching)
            const CircularProgressIndicator()
          else
            Expanded(
              child: _buildResultsList(),
            ),
        ],
      ),
    );
  }

  /// When the user has typed a query, show search results.
  /// When the search box is empty, show a "Recent" picker so users can re-log
  /// foods they've eaten before in one tap (BRD: pick from previously logged foods).
  Widget _buildResultsList() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    if (hasQuery) {
      if (_searchResults.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('No results. Try a different search.'),
          ),
        );
      }
      return ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final food = _searchResults[index];
          return ListTile(
            title: Text(food.name),
            subtitle: Text('${food.calories} kcal | Protein: ${food.protein}g | Carbs: ${food.carbs}g | Fat: ${food.fat}g'),
            trailing: const Icon(Icons.add_circle, color: Colors.teal),
            onTap: () => _logFood(food),
          );
        },
      );
    }

    // Empty query → show recents.
    final recents = context.watch<FoodLogProvider>().distinctRecentFoods;
    if (recents.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Search for a food above, or scan a barcode.\nFoods you log will appear here for quick access.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Recently logged',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: recents.length,
            itemBuilder: (context, index) {
              final food = recents[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(food.name),
                subtitle: Text(
                  'per 100g: ${food.calories} kcal | P ${food.protein.toStringAsFixed(1)}g · C ${food.carbs.toStringAsFixed(1)}g · F ${food.fat.toStringAsFixed(1)}g',
                ),
                trailing: const Icon(Icons.add_circle, color: Colors.teal),
                onTap: () => _logFood(food),
              );
            },
          ),
        ),
      ],
    );
  }
}
