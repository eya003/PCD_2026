import 'package:flutter/material.dart';

enum UserRole { doctor, family }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.doctor:
        return 'Medecin';
      case UserRole.family:
        return 'Famille';
    }
  }

  String get homeTitle {
    switch (this) {
      case UserRole.doctor:
        return 'Accueil Medecin';
      case UserRole.family:
        return 'Accueil Famille';
    }
  }

  String get authSubtitle {
    switch (this) {
      case UserRole.doctor:
        return 'Authentification du compte medecin';
      case UserRole.family:
        return 'Authentification du compte famille';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.doctor:
        return Icons.medical_services_outlined;
      case UserRole.family:
        return Icons.family_restroom_outlined;
    }
  }

  String get description {
    switch (this) {
      case UserRole.doctor:
        return 'Acces au suivi medical et a la gestion des patients.';
      case UserRole.family:
        return 'Acces familial en consultation et suivi du patient.';
    }
  }
}
