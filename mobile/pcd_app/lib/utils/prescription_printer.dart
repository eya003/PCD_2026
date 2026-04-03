import 'prescription_print_models.dart';
import 'prescription_printer_stub.dart'
    if (dart.library.html) 'prescription_printer_web.dart' as impl;

Future<bool> printPrescription(PrescriptionPrintPayload payload) {
  return impl.printPrescription(payload);
}
