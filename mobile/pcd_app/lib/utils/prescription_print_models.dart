class PrescriptionPrintMedication {
  const PrescriptionPrintMedication({
    required this.name,
    required this.dosage,
    required this.frequency,
    this.quantity,
    this.period,
    this.form,
    required this.startDate,
    this.endDate,
    this.instructions,
  });

  final String name;
  final String dosage;
  final String frequency;
  final String? quantity;
  final String? period;
  final String? form;
  final String startDate;
  final String? endDate;
  final String? instructions;
}

class PrescriptionPrintPayload {
  const PrescriptionPrintPayload({
    required this.doctorDisplayName,
    required this.patientFullName,
    required this.patientCode,
    required this.patientCin,
    required this.patientAgeLabel,
    required this.prescriptionNumber,
    required this.prescriptionDate,
    required this.prescriptionStatus,
    this.prescriptionNotes,
    required this.medications,
  });

  final String doctorDisplayName;
  final String patientFullName;
  final String patientCode;
  final String patientCin;
  final String patientAgeLabel;
  final String prescriptionNumber;
  final String prescriptionDate;
  final String prescriptionStatus;
  final String? prescriptionNotes;
  final List<PrescriptionPrintMedication> medications;
}
