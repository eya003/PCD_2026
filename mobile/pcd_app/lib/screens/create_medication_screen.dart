import 'package:flutter/material.dart';

class CreateMedicationScreen extends StatefulWidget {
  const CreateMedicationScreen({super.key, this.patientName});

  final String? patientName;

  @override
  State<CreateMedicationScreen> createState() => _CreateMedicationScreenState();
}

class _CreateMedicationScreenState extends State<CreateMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _startDateController = TextEditingController();

  DateTime? _startDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label obligatoire';
    return null;
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Date de debut',
    );
    if (picked == null) return;

    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      _startDateController.text = _formatDate(_startDate!);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackBar('Veuillez corriger le formulaire.');
      return;
    }

    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    _showSnackBar('Medicament ajoute (placeholder).');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.patientName == null
        ? 'Placeholder UI. API a brancher plus tard.'
        : 'Pour ${widget.patientName} (placeholder UI).';

    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter medicament')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nouveau medicament',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(subtitle),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom',
                            prefixIcon: Icon(Icons.medication_outlined),
                          ),
                          validator: (v) => _validateRequired(v, 'Nom'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _dosageController,
                          decoration: const InputDecoration(
                            labelText: 'Dosage',
                            prefixIcon: Icon(Icons.science_outlined),
                          ),
                          validator: (v) => _validateRequired(v, 'Dosage'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _frequencyController,
                          decoration: const InputDecoration(
                            labelText: 'Frequence',
                            prefixIcon: Icon(Icons.schedule_outlined),
                          ),
                          validator: (v) => _validateRequired(v, 'Frequence'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _startDateController,
                          readOnly: true,
                          onTap: _pickStartDate,
                          decoration: InputDecoration(
                            labelText: 'Date de debut',
                            prefixIcon: const Icon(
                              Icons.calendar_today_outlined,
                            ),
                            suffixIcon: IconButton(
                              onPressed: _pickStartDate,
                              icon: const Icon(Icons.event_outlined),
                            ),
                          ),
                          validator: (v) =>
                              _validateRequired(v, 'Date de debut'),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add),
                            label: Text(
                              _isSubmitting ? 'Ajout...' : 'Ajouter medicament',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
