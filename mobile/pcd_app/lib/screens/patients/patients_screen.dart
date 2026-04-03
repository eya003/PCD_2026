import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/patient_summary.dart';
import '../../models/status_type.dart';
import '../../services/patients_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chips_row.dart';
import '../../widgets/patient_card.dart';
import 'patient_profile_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({
    super.key,
    required this.patientsRevision,
    required this.appointmentsRevision,
  });

  final ValueListenable<int> patientsRevision;
  final ValueNotifier<int> appointmentsRevision;

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  late final PatientsService _service;
  late final VoidCallback _patientsRevisionListener;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  PatientStatus? _statusFilter;
  List<PatientSummary> _patients = const [];

  @override
  void initState() {
    super.initState();
    _service = PatientsService();
    _patientsRevisionListener = _onPatientsRevisionChanged;
    widget.patientsRevision.addListener(_patientsRevisionListener);
    _loadPatients();
  }

  @override
  void dispose() {
    widget.patientsRevision.removeListener(_patientsRevisionListener);
    _searchController.dispose();
    super.dispose();
  }

  void _onPatientsRevisionChanged() {
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.fetchPatients(
        query: _searchController.text,
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _patients = result;
        _isLoading = false;
        _errorMessage = null;
      });
    } on PatientsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Impossible de charger la liste des patients.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPatients,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const AppHeader(
            title: 'Patients',
            subtitle:
                'Recherche rapide, filtres et ouverture de fiche en 1 clic.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppSearchField(
            controller: _searchController,
            hintText: 'Rechercher (ID, nom, CIN, age)...',
            onChanged: (_) => _loadPatients(),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilterChipsRow(
            selectedStatus: _statusFilter,
            onSelected: (status) {
              setState(() => _statusFilter = status);
              _loadPatients();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Chargement impossible',
              message: _errorMessage!,
            )
          else if (_patients.isEmpty)
            const EmptyState(
              icon: Icons.person_search_outlined,
              title: 'Aucun patient',
              message: 'Aucun patient ne correspond a vos criteres.',
            )
          else
            ..._patients.map(
              (patient) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PatientCard(
                  patient: patient,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PatientProfileScreen(
                          patient: patient,
                          appointmentsRevision: widget.appointmentsRevision,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
