class DoseStatusCounts {
  const DoseStatusCounts({
    required this.pending,
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.rescheduled,
    required this.cancelled,
    required this.total,
  });

  factory DoseStatusCounts.empty() {
    return const DoseStatusCounts(
      pending: 0,
      taken: 0,
      missed: 0,
      skipped: 0,
      rescheduled: 0,
      cancelled: 0,
      total: 0,
    );
  }

  factory DoseStatusCounts.fromJson(Map<String, dynamic> json) {
    return DoseStatusCounts(
      pending: _parseInt(json['pending']) ?? 0,
      taken: _parseInt(json['taken']) ?? 0,
      missed: _parseInt(json['missed']) ?? 0,
      skipped: _parseInt(json['skipped']) ?? 0,
      rescheduled: _parseInt(json['rescheduled']) ?? 0,
      cancelled: _parseInt(json['cancelled']) ?? 0,
      total: _parseInt(json['total']) ?? 0,
    );
  }

  final int pending;
  final int taken;
  final int missed;
  final int skipped;
  final int rescheduled;
  final int cancelled;
  final int total;
}

class MedicationDoseSummary {
  const MedicationDoseSummary({
    required this.id,
    required this.name,
    required this.status,
    this.dosage,
    this.frequency,
    this.form,
    this.quantity,
    this.instructions,
  });

  factory MedicationDoseSummary.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final name = (json['name']?.toString() ?? '').trim();
    if (id == null || name.isEmpty) {
      throw const FormatException('Medication summary payload is invalid');
    }

    return MedicationDoseSummary(
      id: id,
      name: name,
      status: (json['status']?.toString() ?? 'active').trim().toLowerCase(),
      dosage: _nullableText(json['dosage']),
      frequency: _nullableText(json['frequency']),
      form: _nullableText(json['form']),
      quantity: _nullableText(json['quantity']),
      instructions: _nullableText(json['instructions']),
    );
  }

  final int id;
  final String name;
  final String status;
  final String? dosage;
  final String? frequency;
  final String? form;
  final String? quantity;
  final String? instructions;
}

class ScheduledDoseIntakeLog {
  const ScheduledDoseIntakeLog({
    required this.id,
    required this.medicationId,
    required this.status,
    this.scheduledDoseId,
    this.validatedBy,
    this.scheduledFor,
    this.takenAt,
    this.comment,
  });

  factory ScheduledDoseIntakeLog.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final medicationId = _parseInt(json['medication_id']);
    final status = (json['status']?.toString() ?? '').trim().toLowerCase();

    if (id == null || medicationId == null || status.isEmpty) {
      throw const FormatException('Dose intake payload is invalid');
    }

    return ScheduledDoseIntakeLog(
      id: id,
      medicationId: medicationId,
      status: status,
      scheduledDoseId: _parseInt(json['scheduled_dose_id']),
      validatedBy: _parseInt(json['validated_by']),
      scheduledFor: _parseDateTime(json['scheduled_for']),
      takenAt: _parseDateTime(json['taken_at']),
      comment: _nullableText(json['comment']),
    );
  }

  final int id;
  final int medicationId;
  final String status;
  final int? scheduledDoseId;
  final int? validatedBy;
  final DateTime? scheduledFor;
  final DateTime? takenAt;
  final String? comment;
}

class ScheduledMedicationDose {
  const ScheduledMedicationDose({
    required this.id,
    required this.patientId,
    required this.medicationId,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.scheduledFor,
    required this.status,
    this.prescriptionId,
    this.periodLabel,
    this.originalScheduledFor,
    this.rescheduledFor,
    this.takenAt,
    this.validatedBy,
    this.validationMethod,
    this.skippedReason,
    this.notes,
    this.medication,
    this.intakes = const [],
  });

  factory ScheduledMedicationDose.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final patientId = _parseInt(json['patient_id']);
    final medicationId = _parseInt(json['medication_id']);
    final scheduledFor = _parseDateTime(json['scheduled_for']);
    final status = (json['status']?.toString() ?? '').trim().toLowerCase();

    final scheduledDate =
        _parseDate(json['scheduled_date']) ?? scheduledFor?.toLocal();
    final scheduledTime = _nullableText(json['scheduled_time']);

    if (id == null ||
        patientId == null ||
        medicationId == null ||
        scheduledFor == null ||
        scheduledDate == null ||
        scheduledTime == null ||
        status.isEmpty) {
      throw const FormatException('Scheduled dose payload is invalid');
    }

    final medicationJson = json['medication'];
    final intakesJson = json['intakes'];

    return ScheduledMedicationDose(
      id: id,
      patientId: patientId,
      medicationId: medicationId,
      prescriptionId: _parseInt(json['prescription_id']),
      scheduledDate: DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
      ),
      scheduledTime: scheduledTime,
      scheduledFor: scheduledFor.toLocal(),
      periodLabel: _nullableText(json['period_label']),
      status: status,
      originalScheduledFor: _parseDateTime(json['original_scheduled_for']),
      rescheduledFor: _parseDateTime(json['rescheduled_for']),
      takenAt: _parseDateTime(json['taken_at']),
      validatedBy: _parseInt(json['validated_by']),
      validationMethod: _nullableText(json['validation_method']),
      skippedReason: _nullableText(json['skipped_reason']),
      notes: _nullableText(json['notes']),
      medication: medicationJson is Map<String, dynamic>
          ? MedicationDoseSummary.fromJson(medicationJson)
          : null,
      intakes: intakesJson is List
          ? intakesJson
                .whereType<Map<String, dynamic>>()
                .map((item) {
                  try {
                    return ScheduledDoseIntakeLog.fromJson(item);
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<ScheduledDoseIntakeLog>()
                .toList()
          : const [],
    );
  }

  static const statusPending = 'pending';
  static const statusTaken = 'taken';
  static const statusMissed = 'missed';
  static const statusSkipped = 'skipped';
  static const statusRescheduled = 'rescheduled';
  static const statusCancelled = 'cancelled';

  final int id;
  final int patientId;
  final int medicationId;
  final int? prescriptionId;
  final DateTime scheduledDate;
  final String scheduledTime;
  final DateTime scheduledFor;
  final String? periodLabel;
  final String status;
  final DateTime? originalScheduledFor;
  final DateTime? rescheduledFor;
  final DateTime? takenAt;
  final int? validatedBy;
  final String? validationMethod;
  final String? skippedReason;
  final String? notes;
  final MedicationDoseSummary? medication;
  final List<ScheduledDoseIntakeLog> intakes;

  String get normalizedStatus => status.trim().toLowerCase();

  bool get canBeActedOn => normalizedStatus == statusPending;

  DateTime get effectiveScheduledFor =>
      (rescheduledFor ?? scheduledFor).toLocal();

  String get statusLabelFr {
    switch (normalizedStatus) {
      case statusTaken:
        return 'Pris';
      case statusMissed:
        return 'Manquee';
      case statusSkipped:
        return 'Sautee';
      case statusRescheduled:
        return 'Replanifiee';
      case statusCancelled:
        return 'Annulee';
      case statusPending:
      default:
        return 'En attente';
    }
  }
}

class MedicationDayPlanning {
  const MedicationDayPlanning({
    required this.patientId,
    required this.date,
    required this.doses,
    required this.counts,
  });

  factory MedicationDayPlanning.fromJson(Map<String, dynamic> json) {
    final patientId = _parseInt(json['patient_id']);
    final date = _parseDate(json['date']);
    if (patientId == null || date == null) {
      throw const FormatException('Day planning payload is invalid');
    }

    final dosesJson = json['doses'];
    final countsJson = json['counts'];

    return MedicationDayPlanning(
      patientId: patientId,
      date: DateTime(date.year, date.month, date.day),
      doses: dosesJson is List
          ? dosesJson
                .whereType<Map<String, dynamic>>()
                .map(ScheduledMedicationDose.fromJson)
                .toList()
          : const [],
      counts: countsJson is Map<String, dynamic>
          ? DoseStatusCounts.fromJson(countsJson)
          : DoseStatusCounts.empty(),
    );
  }

  final int patientId;
  final DateTime date;
  final List<ScheduledMedicationDose> doses;
  final DoseStatusCounts counts;
}

class MedicationPlanningDayBucket {
  const MedicationPlanningDayBucket({
    required this.date,
    required this.doses,
    required this.counts,
  });

  factory MedicationPlanningDayBucket.fromJson(Map<String, dynamic> json) {
    final date = _parseDate(json['date']);
    if (date == null) {
      throw const FormatException('Planning day bucket payload is invalid');
    }

    final dosesJson = json['doses'];
    final countsJson = json['counts'];

    return MedicationPlanningDayBucket(
      date: DateTime(date.year, date.month, date.day),
      doses: dosesJson is List
          ? dosesJson
                .whereType<Map<String, dynamic>>()
                .map(ScheduledMedicationDose.fromJson)
                .toList()
          : const [],
      counts: countsJson is Map<String, dynamic>
          ? DoseStatusCounts.fromJson(countsJson)
          : DoseStatusCounts.empty(),
    );
  }

  final DateTime date;
  final List<ScheduledMedicationDose> doses;
  final DoseStatusCounts counts;
}

class MedicationDateRangePlanning {
  const MedicationDateRangePlanning({
    required this.patientId,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.counts,
  });

  factory MedicationDateRangePlanning.fromJson(Map<String, dynamic> json) {
    final patientId = _parseInt(json['patient_id']);
    final startDate = _parseDate(json['start_date']);
    final endDate = _parseDate(json['end_date']);

    if (patientId == null || startDate == null || endDate == null) {
      throw const FormatException('Date range planning payload is invalid');
    }

    final daysJson = json['days'];
    final countsJson = json['counts'];

    return MedicationDateRangePlanning(
      patientId: patientId,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: DateTime(endDate.year, endDate.month, endDate.day),
      days: daysJson is List
          ? daysJson
                .whereType<Map<String, dynamic>>()
                .map(MedicationPlanningDayBucket.fromJson)
                .toList()
          : const [],
      counts: countsJson is Map<String, dynamic>
          ? DoseStatusCounts.fromJson(countsJson)
          : DoseStatusCounts.empty(),
    );
  }

  final int patientId;
  final DateTime startDate;
  final DateTime endDate;
  final List<MedicationPlanningDayBucket> days;
  final DoseStatusCounts counts;
}

class MedicationScheduleTemplate {
  const MedicationScheduleTemplate({
    required this.id,
    required this.patientId,
    required this.morningTime,
    required this.noonTime,
    required this.eveningTime,
    required this.dayStartTime,
    required this.dayEndTime,
    required this.reminderOffsetMinutes,
    required this.allowFamilyAdjustment,
    required this.isActive,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory MedicationScheduleTemplate.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final patientId = _parseInt(json['patient_id']);
    final morningTime = _nullableText(json['morning_time']);
    final noonTime = _nullableText(json['noon_time']);
    final eveningTime = _nullableText(json['evening_time']);
    final dayStartTime = _nullableText(json['day_start_time']);
    final dayEndTime = _nullableText(json['day_end_time']);

    if (id == null ||
        patientId == null ||
        morningTime == null ||
        noonTime == null ||
        eveningTime == null ||
        dayStartTime == null ||
        dayEndTime == null) {
      throw const FormatException('Schedule template payload is invalid');
    }

    return MedicationScheduleTemplate(
      id: id,
      patientId: patientId,
      createdBy: _parseInt(json['created_by']),
      morningTime: morningTime,
      noonTime: noonTime,
      eveningTime: eveningTime,
      dayStartTime: dayStartTime,
      dayEndTime: dayEndTime,
      reminderOffsetMinutes: _parseInt(json['reminder_offset_minutes']) ?? 10,
      allowFamilyAdjustment:
          _parseBool(json['allow_family_adjustment']) ?? true,
      isActive: _parseBool(json['is_active']) ?? true,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  final int id;
  final int patientId;
  final int? createdBy;
  final String morningTime;
  final String noonTime;
  final String eveningTime;
  final String dayStartTime;
  final String dayEndTime;
  final int reminderOffsetMinutes;
  final bool allowFamilyAdjustment;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class MedicationScheduleTemplateUpdate {
  const MedicationScheduleTemplateUpdate({
    this.morningTime,
    this.noonTime,
    this.eveningTime,
    this.dayStartTime,
    this.dayEndTime,
    this.reminderOffsetMinutes,
    this.allowFamilyAdjustment,
    this.isActive,
  });

  final String? morningTime;
  final String? noonTime;
  final String? eveningTime;
  final String? dayStartTime;
  final String? dayEndTime;
  final int? reminderOffsetMinutes;
  final bool? allowFamilyAdjustment;
  final bool? isActive;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (morningTime != null) 'morning_time': morningTime,
      if (noonTime != null) 'noon_time': noonTime,
      if (eveningTime != null) 'evening_time': eveningTime,
      if (dayStartTime != null) 'day_start_time': dayStartTime,
      if (dayEndTime != null) 'day_end_time': dayEndTime,
      if (reminderOffsetMinutes != null)
        'reminder_offset_minutes': reminderOffsetMinutes,
      if (allowFamilyAdjustment != null)
        'allow_family_adjustment': allowFamilyAdjustment,
      if (isActive != null) 'is_active': isActive,
    };
  }
}

class ScheduledDoseTakeActionPayload {
  const ScheduledDoseTakeActionPayload({
    this.takenAt,
    this.validationMethod = 'manual',
    this.notes,
    this.comment,
    this.createIntakeLog = true,
  });

  final DateTime? takenAt;
  final String validationMethod;
  final String? notes;
  final String? comment;
  final bool createIntakeLog;

  Map<String, dynamic> toJson() {
    return {
      if (takenAt != null) 'taken_at': takenAt!.toUtc().toIso8601String(),
      'validation_method': validationMethod,
      if (_hasText(notes)) 'notes': notes!.trim(),
      if (_hasText(comment)) 'comment': comment!.trim(),
      'create_intake_log': createIntakeLog,
    };
  }
}

class ScheduledDoseMissActionPayload {
  const ScheduledDoseMissActionPayload({
    this.missedAt,
    this.validationMethod = 'manual',
    this.notes,
    this.comment,
    this.createIntakeLog = true,
  });

  final DateTime? missedAt;
  final String validationMethod;
  final String? notes;
  final String? comment;
  final bool createIntakeLog;

  Map<String, dynamic> toJson() {
    return {
      if (missedAt != null) 'missed_at': missedAt!.toUtc().toIso8601String(),
      'validation_method': validationMethod,
      if (_hasText(notes)) 'notes': notes!.trim(),
      if (_hasText(comment)) 'comment': comment!.trim(),
      'create_intake_log': createIntakeLog,
    };
  }
}

class ScheduledDoseSkipActionPayload {
  const ScheduledDoseSkipActionPayload({
    required this.skippedReason,
    this.skippedAt,
    this.validationMethod = 'manual',
    this.notes,
    this.comment,
    this.createIntakeLog = true,
  });

  final String skippedReason;
  final DateTime? skippedAt;
  final String validationMethod;
  final String? notes;
  final String? comment;
  final bool createIntakeLog;

  Map<String, dynamic> toJson() {
    return {
      'skipped_reason': skippedReason.trim(),
      if (skippedAt != null) 'skipped_at': skippedAt!.toUtc().toIso8601String(),
      'validation_method': validationMethod,
      if (_hasText(notes)) 'notes': notes!.trim(),
      if (_hasText(comment)) 'comment': comment!.trim(),
      'create_intake_log': createIntakeLog,
    };
  }
}

class ScheduledDoseRescheduleActionPayload {
  const ScheduledDoseRescheduleActionPayload({
    required this.rescheduledFor,
    this.reason,
    this.notes,
    this.validationMethod = 'manual',
  });

  final DateTime rescheduledFor;
  final String? reason;
  final String? notes;
  final String validationMethod;

  Map<String, dynamic> toJson() {
    return {
      'rescheduled_for': rescheduledFor.toUtc().toIso8601String(),
      if (_hasText(reason)) 'reason': reason!.trim(),
      if (_hasText(notes)) 'notes': notes!.trim(),
      'validation_method': validationMethod,
    };
  }
}

class ScheduledDoseCancelActionPayload {
  const ScheduledDoseCancelActionPayload({this.reason, this.notes});

  final String? reason;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      if (_hasText(reason)) 'reason': reason!.trim(),
      if (_hasText(notes)) 'notes': notes!.trim(),
    };
  }
}

class ScheduledDoseActionResult {
  const ScheduledDoseActionResult({required this.dose, this.intake});

  factory ScheduledDoseActionResult.fromJson(Map<String, dynamic> json) {
    final doseJson = json['dose'];
    if (doseJson is! Map<String, dynamic>) {
      throw const FormatException('Scheduled dose action result is invalid');
    }

    final intakeJson = json['intake'];
    return ScheduledDoseActionResult(
      dose: ScheduledMedicationDose.fromJson(doseJson),
      intake: intakeJson is Map<String, dynamic>
          ? ScheduledDoseIntakeLog.fromJson(intakeJson)
          : null,
    );
  }

  final ScheduledMedicationDose dose;
  final ScheduledDoseIntakeLog? intake;
}

bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _parseDate(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _parseDateTime(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  return parsed?.toLocal();
}

bool? _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return null;
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
