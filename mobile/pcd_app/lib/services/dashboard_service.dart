import 'package:flutter/material.dart';

import '../models/ai_result_item.dart';
import '../models/alert_item.dart';
import '../models/appointment_item.dart';
import '../models/dashboard_kpi.dart';
import '../models/patient_summary.dart';
import '../models/status_type.dart';
import 'appointments_service.dart';
import 'patients_service.dart';

class DashboardData {
  const DashboardData({
    required this.kpis,
    required this.appointments,
    required this.patients,
  });

  final List<DashboardKpi> kpis;
  final List<AppointmentItem> appointments;
  final List<PatientSummary> patients;
}

class DashboardService {
  DashboardService({
    PatientsService? patientsService,
    AppointmentsService? appointmentsService,
  }) : _patientsService = patientsService ?? PatientsService(),
       _appointmentsService = appointmentsService ?? AppointmentsService();

  final PatientsService _patientsService;
  final AppointmentsService _appointmentsService;

  Future<DashboardData> fetchDashboardData() async {
    final patients = await _patientsService.fetchDoctorPatients();
    final patientsById = <int, PatientSummary>{for (final p in patients) p.id: p};
    final appointments = await _appointmentsService.fetchDoctorAppointments(
      patientsById: patientsById,
    );

    final today = DateTime.now();
    final todayAppointmentsCount = appointments.where((item) {
      return item.dateTime.year == today.year &&
          item.dateTime.month == today.month &&
          item.dateTime.day == today.day;
    }).length;

    return DashboardData(
      kpis: [
        DashboardKpi(
          title: 'Patients',
          value: '${patients.length}',
          subtitle: 'Total patients lies a votre compte',
          icon: Icons.groups_outlined,
          badge: 'Reel',
          badgeTone: BadgeTone.neutral,
        ),
        DashboardKpi(
          title: 'Rendez-vous (aujourdhui)',
          value: '$todayAppointmentsCount',
          subtitle: 'Planifies pour la journee',
          icon: Icons.event_note_outlined,
          badge: 'Aujourdhui',
          badgeTone: BadgeTone.primary,
        ),
        const DashboardKpi(
          title: 'Alertes',
          value: '2',
          subtitle: 'Alertes recentes a traiter',
          icon: Icons.notifications_active_outlined,
          badge: 'A verifier',
          badgeTone: BadgeTone.warning,
        ),
        const DashboardKpi(
          title: 'IA',
          value: '--',
          subtitle: 'Dernier run: CN (77%)',
          icon: Icons.psychology_alt_outlined,
          badge: 'Resultats',
          badgeTone: BadgeTone.neutral,
        ),
      ],
      appointments: appointments,
      patients: patients,
    );
  }

  Future<List<AlertItem>> fetchRecentAlerts() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const [
      AlertItem(
        id: 1,
        type: 'GEOFENCE_EXIT',
        patientName: 'Ahmed Ben Salah',
        message: 'Sortie de zone detectee',
        dateLabel: '18 fev. 2026, 09:12',
      ),
      AlertItem(
        id: 2,
        type: 'MED_MISSED',
        patientName: 'Sara Trabelsi',
        message: 'Medicament non valide',
        dateLabel: '17 fev. 2026, 20:05',
      ),
    ];
  }

  Future<List<AiResultItem>> fetchLatestAiResults() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const [
      AiResultItem(
        id: 1,
        patientName: 'Ahmed Ben Salah',
        modelName: 'CN',
        score: 77,
        dateLabel: '18 fev. 2026',
        summary: 'Score stable, recommandation de suivi standard.',
      ),
      AiResultItem(
        id: 2,
        patientName: 'Sara Trabelsi',
        modelName: 'CN',
        score: 64,
        dateLabel: '17 fev. 2026',
        summary: 'Variabilite elevee, verification clinique recommandee.',
      ),
    ];
  }
}
