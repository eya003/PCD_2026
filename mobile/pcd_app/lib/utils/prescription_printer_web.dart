import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'prescription_print_models.dart';

Future<bool> printPrescription(PrescriptionPrintPayload payload) async {
  try {
    final opened = html.window.open('', '_blank', 'width=1024,height=900');
    if (opened == null) {
      return false;
    }

    final printWindow = opened as html.Window;
    final document = js_util.getProperty(printWindow, 'document');

    js_util.callMethod(document, 'open', []);
    js_util.callMethod(document, 'write', [_buildPrintableHtml(payload)]);
    js_util.callMethod(document, 'close', []);

    await Future<void>.delayed(const Duration(milliseconds: 300));

    js_util.callMethod(printWindow, 'focus', []);
    js_util.callMethod(printWindow, 'print', []);

    return true;
  } catch (_) {
    return false;
  }
}

String _buildPrintableHtml(PrescriptionPrintPayload payload) {
  final notes = _clean(payload.prescriptionNotes);
  final renderedNotes = notes.isEmpty
      ? ''
      : '<section class="card"><h2>Notes</h2><p>${_esc(notes)}</p></section>';

  final medications = payload.medications.asMap().entries.map((entry) {
    final index = entry.key + 1;
    final item = entry.value;

    final rows = <String>[
      _metaRow('Dosage', item.dosage),
      _metaRow('Frequence', item.frequency),
      _metaRow('Date debut', item.startDate),
    ];

    final quantity = _clean(item.quantity);
    if (quantity.isNotEmpty) {
      rows.add(_metaRow('Quantite', quantity));
    }

    final period = _clean(item.period);
    if (period.isNotEmpty) {
      rows.add(_metaRow('Periode', period));
    }

    final form = _clean(item.form);
    if (form.isNotEmpty) {
      rows.add(_metaRow('Forme', form));
    }

    final endDate = _clean(item.endDate);
    if (endDate.isNotEmpty) {
      rows.add(_metaRow('Date fin', endDate));
    }

    final instructions = _clean(item.instructions);

    return '''
      <article class="medication">
        <h3>$index. ${_esc(item.name)}</h3>
        <div class="grid">
          ${rows.join()}
        </div>
        ${
          instructions.isEmpty
              ? ''
              : '<p class="instructions"><strong>Instructions:</strong> ${_esc(instructions)}</p>'
        }
      </article>
    ''';
  }).join();

  return '''
<!DOCTYPE html>
<html lang="fr">
  <head>
    <meta charset="utf-8" />
    <title>Ordonnance ${_esc(payload.prescriptionNumber)}</title>
    <style>
      @page {
        size: A4;
        margin: 15mm;
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        color: #0f172a;
        font-family: "Segoe UI", Arial, sans-serif;
        font-size: 12px;
        line-height: 1.45;
      }

      main {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }

      .head {
        border-bottom: 2px solid #0f172a;
        padding-bottom: 8px;
      }

      .doctor {
        font-size: 20px;
        font-weight: 700;
        margin-bottom: 4px;
      }

      .subtitle {
        color: #475569;
      }

      .card {
        border: 1px solid #dbe2ea;
        border-radius: 8px;
        padding: 10px 12px;
      }

      h2 {
        margin: 0 0 8px;
        font-size: 14px;
      }

      .grid {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 6px 10px;
      }

      .row {
        padding: 3px 0;
        border-bottom: 1px dashed #e2e8f0;
      }

      .label {
        display: inline-block;
        min-width: 95px;
        color: #334155;
        font-weight: 600;
      }

      .medication {
        border: 1px solid #dbe2ea;
        border-radius: 8px;
        padding: 10px 12px;
        margin-top: 10px;
        break-inside: avoid-page;
      }

      .medication h3 {
        margin: 0 0 8px;
        font-size: 13px;
      }

      .instructions {
        margin: 10px 0 0;
      }

      .badge {
        display: inline-block;
        margin-left: 6px;
        padding: 2px 8px;
        border-radius: 999px;
        border: 1px solid #cbd5e1;
        background: #f8fafc;
        font-size: 11px;
        font-weight: 600;
      }
    </style>
  </head>
  <body>
    <main>
      <header class="head">
        <div class="doctor">${_esc(payload.doctorDisplayName)}</div>
        <div class="subtitle">Ordonnance medicale</div>
      </header>

      <section class="card">
        <h2>Informations patient</h2>
        <div class="grid">
          ${_metaRow('Patient', payload.patientFullName)}
          ${_metaRow('Code', payload.patientCode)}
          ${_metaRow('CIN', payload.patientCin)}
          ${_metaRow('Age', payload.patientAgeLabel)}
        </div>
      </section>

      <section class="card">
        <h2>Informations ordonnance</h2>
        <div class="grid">
          ${_metaRow('Numero', payload.prescriptionNumber)}
          ${_metaRow('Date', payload.prescriptionDate)}
          <div class="row"><span class="label">Statut</span><span class="badge">${_esc(payload.prescriptionStatus)}</span></div>
          ${_metaRow('Lignes', payload.medications.length.toString())}
        </div>
      </section>

      $renderedNotes

      <section>
        <h2>Medicaments</h2>
        $medications
      </section>
    </main>
  </body>
</html>
''';
}

String _metaRow(String label, String value) {
  return '<div class="row"><span class="label">${_esc(label)}</span>${_esc(value)}</div>';
}

String _clean(String? value) {
  return value?.trim() ?? '';
}

String _esc(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}