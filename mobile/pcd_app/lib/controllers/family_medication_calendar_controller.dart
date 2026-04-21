import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/medication_calendar.dart';
import '../services/medication_calendar_service.dart';

class FamilyMedicationCalendarController extends ChangeNotifier {
  FamilyMedicationCalendarController({MedicationCalendarService? service})
    : _service = service ?? MedicationCalendarService();

  final MedicationCalendarService _service;

  int? _patientId;

  DateTime selectedDay = _normalizeDate(DateTime.now());
  DateTime rangeStart = _normalizeDate(
    DateTime.now().subtract(const Duration(days: 3)),
  );
  DateTime rangeEnd = _normalizeDate(
    DateTime.now().add(const Duration(days: 3)),
  );

  MedicationDayPlanning? todayPlanning;
  MedicationDateRangePlanning? rangePlanning;
  MedicationScheduleTemplate? template;

  bool isLoadingToday = false;
  bool isLoadingRange = false;
  bool isLoadingTemplate = false;
  bool isMutating = false;

  String? todayError;
  String? rangeError;
  String? templateError;
  String? mutationError;

  bool hasChanges = false;

  Future<void> initialize({
    required int patientId,
    required bool loadTemplate,
  }) async {
    _patientId = patientId;
    await Future.wait([
      loadToday(),
      loadRange(),
      if (loadTemplate) loadScheduleTemplate(),
    ]);
  }

  Future<void> reloadAll({required bool includeTemplate}) async {
    await Future.wait([
      loadToday(),
      loadRange(),
      if (includeTemplate) loadScheduleTemplate(),
    ]);
  }

  Future<void> loadToday({DateTime? day, bool silent = false}) async {
    final patientId = _requiredPatientId();
    if (day != null) {
      selectedDay = _normalizeDate(day);
    }
    if (!silent) {
      isLoadingToday = true;
      todayError = null;
      notifyListeners();
    }

    try {
      todayPlanning = await _service.fetchTodayPlanning(
        patientId: patientId,
        planningDate: selectedDay,
      );
      todayError = null;
    } on MedicationCalendarException catch (e) {
      todayError = e.message;
    } catch (_) {
      todayError = 'Impossible de charger le planning du jour.';
    } finally {
      isLoadingToday = false;
      notifyListeners();
    }
  }

  Future<void> shiftSelectedDay(int deltaDays) async {
    await loadToday(day: selectedDay.add(Duration(days: deltaDays)));
  }

  Future<void> setRange(
    DateTime start,
    DateTime end, {
    bool silent = false,
  }) async {
    final normalizedStart = _normalizeDate(start);
    final normalizedEnd = _normalizeDate(end);
    if (normalizedEnd.isBefore(normalizedStart)) {
      rangeError = 'La date de fin doit etre >= a la date de debut.';
      notifyListeners();
      return;
    }

    rangeStart = normalizedStart;
    rangeEnd = normalizedEnd;
    await loadRange(silent: silent);
  }

  Future<void> loadRange({bool silent = false}) async {
    final patientId = _requiredPatientId();
    if (!silent) {
      isLoadingRange = true;
      rangeError = null;
      notifyListeners();
    }

    try {
      rangePlanning = await _service.fetchRangePlanning(
        patientId: patientId,
        startDate: rangeStart,
        endDate: rangeEnd,
      );
      rangeError = null;
    } on MedicationCalendarException catch (e) {
      rangeError = e.message;
    } catch (_) {
      rangeError = 'Impossible de charger le planning calendrier.';
    } finally {
      isLoadingRange = false;
      notifyListeners();
    }
  }

  Future<void> loadScheduleTemplate() async {
    final patientId = _requiredPatientId();
    isLoadingTemplate = true;
    templateError = null;
    notifyListeners();

    try {
      template = await _service.fetchPatientScheduleTemplate(
        patientId: patientId,
      );
      templateError = null;
    } on MedicationCalendarException catch (e) {
      templateError = e.message;
    } catch (_) {
      templateError = 'Impossible de charger le template de planning.';
    } finally {
      isLoadingTemplate = false;
      notifyListeners();
    }
  }

  Future<MedicationScheduleTemplate?> updateScheduleTemplate(
    MedicationScheduleTemplateUpdate payload,
  ) async {
    final patientId = _requiredPatientId();
    isMutating = true;
    mutationError = null;
    notifyListeners();

    try {
      final updated = await _service.updatePatientScheduleTemplate(
        patientId: patientId,
        payload: payload,
      );
      template = updated;
      hasChanges = true;
      templateError = null;
      return updated;
    } on MedicationCalendarException catch (e) {
      mutationError = e.message;
      return null;
    } catch (_) {
      mutationError = 'Impossible de mettre a jour le template.';
      return null;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<ScheduledDoseActionResult?> takeDose(
    int doseId, {
    ScheduledDoseTakeActionPayload payload =
        const ScheduledDoseTakeActionPayload(),
  }) async {
    return _runDoseMutation(
      () => _service.takeScheduledDose(doseId: doseId, payload: payload),
    );
  }

  Future<ScheduledDoseActionResult?> missDose(
    int doseId, {
    ScheduledDoseMissActionPayload payload =
        const ScheduledDoseMissActionPayload(),
  }) async {
    return _runDoseMutation(
      () => _service.missScheduledDose(doseId: doseId, payload: payload),
    );
  }

  Future<ScheduledDoseActionResult?> skipDose(
    int doseId, {
    required ScheduledDoseSkipActionPayload payload,
  }) async {
    return _runDoseMutation(
      () => _service.skipScheduledDose(doseId: doseId, payload: payload),
    );
  }

  Future<ScheduledDoseActionResult?> rescheduleDose(
    int doseId, {
    required ScheduledDoseRescheduleActionPayload payload,
  }) async {
    return _runDoseMutation(
      () => _service.rescheduleScheduledDose(doseId: doseId, payload: payload),
    );
  }

  Future<ScheduledDoseActionResult?> cancelDose(
    int doseId, {
    ScheduledDoseCancelActionPayload payload =
        const ScheduledDoseCancelActionPayload(),
  }) async {
    return _runDoseMutation(
      () => _service.cancelScheduledDose(doseId: doseId, payload: payload),
    );
  }

  Future<ScheduledMedicationDose?> fetchDoseDetail(int doseId) async {
    try {
      return await _service.fetchScheduledDoseDetail(doseId: doseId);
    } on MedicationCalendarException catch (e) {
      mutationError = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      mutationError = 'Impossible de charger le detail de la dose.';
      notifyListeners();
      return null;
    }
  }

  Future<ScheduledDoseActionResult?> _runDoseMutation(
    Future<ScheduledDoseActionResult> Function() action,
  ) async {
    isMutating = true;
    mutationError = null;
    notifyListeners();

    try {
      final result = await action();
      hasChanges = true;
      await Future.wait([loadToday(silent: true), loadRange(silent: true)]);
      return result;
    } on MedicationCalendarException catch (e) {
      mutationError = e.message;
      return null;
    } catch (_) {
      mutationError = 'Action impossible sur la dose selectionnee.';
      return null;
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  int _requiredPatientId() {
    final value = _patientId;
    if (value == null) {
      throw StateError('Controller not initialized with patient id');
    }
    return value;
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
