enum PatientStatus { suivi, nouveau, aVerifier }

extension PatientStatusX on PatientStatus {
  String get label {
    switch (this) {
      case PatientStatus.suivi:
        return 'Suivi';
      case PatientStatus.nouveau:
        return 'Nouveau';
      case PatientStatus.aVerifier:
        return 'A verifier';
    }
  }
}

enum BadgeTone { neutral, primary, success, warning }
