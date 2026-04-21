from collections import Counter
from datetime import date, datetime, timedelta

import pytest

from app import models


def _create_medication(
    client,
    *,
    patient_id: int,
    auth_headers: dict[str, str],
    frequency: str = "3/j",
    period: str = "5 days",
    start_date: date | None = None,
    is_as_needed: bool = False,
):
    effective_start = start_date or (date.today() + timedelta(days=1))
    payload = {
        "patient_id": patient_id,
        "name": "Amoxicillin",
        "dosage": "500mg",
        "frequency": frequency,
        "period": period,
        "start_date": effective_start.isoformat(),
        "instructions": "After meals",
        "is_as_needed": is_as_needed,
    }
    response = client.post("/medications/", json=payload, headers=auth_headers)
    assert response.status_code == 201, response.text
    return response.json(), effective_start


def _list_scheduled_doses(
    client,
    *,
    medication_id: int,
    auth_headers: dict[str, str],
    start_date: date,
    end_date: date,
):
    response = client.get(
        f"/medication-calendar/medications/{medication_id}/scheduled-doses",
        params={
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
        },
        headers=auth_headers,
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_create_simple_medication_generates_expected_schedule(
    client,
    seeded_access_context,
):
    medication, start_date = _create_medication(
        client,
        patient_id=seeded_access_context["patient"].id,
        auth_headers=seeded_access_context["doctor_headers"],
        frequency="3/j",
        period="5 days",
    )
    end_date = start_date + timedelta(days=4)

    doses = _list_scheduled_doses(
        client,
        medication_id=medication["id"],
        auth_headers=seeded_access_context["doctor_headers"],
        start_date=start_date,
        end_date=end_date,
    )

    assert medication["intake_count_per_day"] == 3
    assert medication["duration_days"] == 5
    assert medication["schedule_mode"] == "default_times"
    assert len(doses) == 15
    assert {dose["status"] for dose in doses} == {"pending"}
    per_day = Counter(dose["scheduled_date"] for dose in doses)
    assert set(per_day.values()) == {3}


def test_planning_today_returns_expected_day_bucket(
    client,
    seeded_access_context,
):
    medication, planning_date = _create_medication(
        client,
        patient_id=seeded_access_context["patient"].id,
        auth_headers=seeded_access_context["doctor_headers"],
    )
    assert medication["id"] > 0

    response = client.get(
        f"/medication-calendar/patients/{seeded_access_context['patient'].id}/planning/today",
        params={"planning_date": planning_date.isoformat()},
        headers=seeded_access_context["doctor_headers"],
    )
    assert response.status_code == 200, response.text
    data = response.json()

    assert data["patient_id"] == seeded_access_context["patient"].id
    assert data["date"] == planning_date.isoformat()
    assert data["counts"]["pending"] == 3
    assert data["counts"]["total"] == 3
    assert len(data["doses"]) == 3


def test_planning_range_returns_expected_totals(
    client,
    seeded_access_context,
):
    _, start_date = _create_medication(
        client,
        patient_id=seeded_access_context["patient"].id,
        auth_headers=seeded_access_context["doctor_headers"],
    )
    end_date = start_date + timedelta(days=4)

    response = client.get(
        f"/medication-calendar/patients/{seeded_access_context['patient'].id}/planning",
        params={
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
        },
        headers=seeded_access_context["doctor_headers"],
    )
    assert response.status_code == 200, response.text
    data = response.json()

    assert data["counts"]["total"] == 15
    assert data["counts"]["pending"] == 15
    assert len(data["days"]) == 5
    assert all(day["counts"]["total"] == 3 for day in data["days"])


@pytest.mark.parametrize(
    ("action", "payload_builder", "expected_dose_status", "expected_intake_status"),
    [
        ("take", lambda _: {}, "taken", "taken"),
        ("miss", lambda _: {}, "missed", "missed"),
        (
            "skip",
            lambda _: {"skipped_reason": "Patient asleep"},
            "skipped",
            "skipped",
        ),
        (
            "reschedule",
            lambda scheduled_for: {
                "rescheduled_for": (
                    scheduled_for + timedelta(minutes=37)
                ).isoformat(),
                "reason": "Late dinner",
            },
            "rescheduled",
            "rescheduled",
        ),
        ("cancel", lambda _: {"reason": "Doctor order"}, "cancelled", None),
    ],
)
def test_scheduled_dose_actions_update_status_and_logs(
    client,
    db_session,
    seeded_access_context,
    action,
    payload_builder,
    expected_dose_status,
    expected_intake_status,
):
    medication, start_date = _create_medication(
        client,
        patient_id=seeded_access_context["patient"].id,
        auth_headers=seeded_access_context["doctor_headers"],
        frequency="1/j",
        period="2 days",
    )
    doses = _list_scheduled_doses(
        client,
        medication_id=medication["id"],
        auth_headers=seeded_access_context["doctor_headers"],
        start_date=start_date,
        end_date=start_date + timedelta(days=1),
    )
    dose_id = doses[0]["id"]
    scheduled_for = datetime.fromisoformat(doses[0]["scheduled_for"])

    response = client.post(
        f"/medication-calendar/scheduled-doses/{dose_id}/{action}",
        json=payload_builder(scheduled_for),
        headers=seeded_access_context["family_admin_headers"],
    )
    assert response.status_code == 200, response.text
    body = response.json()

    assert body["dose"]["status"] == expected_dose_status

    db_dose = db_session.get(models.ScheduledMedicationDose, dose_id)
    assert db_dose is not None
    assert db_dose.status == expected_dose_status

    linked_intakes = (
        db_session.query(models.MedicationIntake)
        .filter(models.MedicationIntake.scheduled_dose_id == dose_id)
        .order_by(models.MedicationIntake.id.asc())
        .all()
    )
    if expected_intake_status is None:
        assert body["intake"] is None
        assert linked_intakes == []
    else:
        assert body["intake"] is not None
        assert body["intake"]["status"] == expected_intake_status
        assert len(linked_intakes) == 1
        assert linked_intakes[0].status == expected_intake_status

    if action == "reschedule":
        successor_slot = datetime.fromisoformat(
            payload_builder(scheduled_for)["rescheduled_for"]
        )
        successor = (
            db_session.query(models.ScheduledMedicationDose)
            .filter(models.ScheduledMedicationDose.medication_id == medication["id"])
            .filter(models.ScheduledMedicationDose.scheduled_for == successor_slot)
            .first()
        )
        assert successor is not None
        assert successor.status == "pending"


def test_is_as_needed_does_not_generate_scheduled_doses(
    client,
    db_session,
    seeded_access_context,
):
    medication, start_date = _create_medication(
        client,
        patient_id=seeded_access_context["patient"].id,
        auth_headers=seeded_access_context["doctor_headers"],
        is_as_needed=True,
    )
    doses = _list_scheduled_doses(
        client,
        medication_id=medication["id"],
        auth_headers=seeded_access_context["doctor_headers"],
        start_date=start_date,
        end_date=start_date + timedelta(days=10),
    )
    assert doses == []

    db_count = (
        db_session.query(models.ScheduledMedicationDose)
        .filter(models.ScheduledMedicationDose.medication_id == medication["id"])
        .count()
    )
    assert db_count == 0


def test_update_medication_recalculates_future_doses(
    client,
    db_session,
    seeded_access_context,
):
    medication, _ = _create_medication(
        client,
        patient_id=seeded_access_context["patient"].id,
        auth_headers=seeded_access_context["doctor_headers"],
    )

    initial_pending = (
        db_session.query(models.ScheduledMedicationDose)
        .filter(models.ScheduledMedicationDose.medication_id == medication["id"])
        .filter(models.ScheduledMedicationDose.status == "pending")
        .count()
    )
    assert initial_pending == 15

    update_response = client.put(
        f"/medications/{medication['id']}",
        json={"intake_count_per_day": 2},
        headers=seeded_access_context["doctor_headers"],
    )
    assert update_response.status_code == 200, update_response.text

    statuses = (
        db_session.query(models.ScheduledMedicationDose.status)
        .filter(models.ScheduledMedicationDose.medication_id == medication["id"])
        .all()
    )
    status_counts = Counter(status for (status,) in statuses)
    assert status_counts["pending"] == 10
    assert status_counts["cancelled"] == 5


@pytest.mark.parametrize(
    ("endpoint", "expected_medication_status"),
    [
        ("complete", "completed"),
        ("cancel", "stopped"),
    ],
)
def test_complete_or_cancel_medication_cancels_future_doses(
    client,
    db_session,
    seeded_access_context,
    endpoint,
    expected_medication_status,
):
    medication, _ = _create_medication(
        client,
        patient_id=seeded_access_context["patient"].id,
        auth_headers=seeded_access_context["doctor_headers"],
    )

    response = client.patch(
        f"/medications/{medication['id']}/{endpoint}",
        headers=seeded_access_context["doctor_headers"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["status"] == expected_medication_status

    statuses = (
        db_session.query(models.ScheduledMedicationDose.status)
        .filter(models.ScheduledMedicationDose.medication_id == medication["id"])
        .all()
    )
    assert len(statuses) == 15
    assert {status for (status,) in statuses} == {"cancelled"}


def test_family_viewer_has_read_only_access_to_dose_actions(
    client,
    seeded_access_context,
):
    medication, planning_date = _create_medication(
        client,
        patient_id=seeded_access_context["patient"].id,
        auth_headers=seeded_access_context["doctor_headers"],
        frequency="1/j",
        period="2 days",
    )
    doses = _list_scheduled_doses(
        client,
        medication_id=medication["id"],
        auth_headers=seeded_access_context["doctor_headers"],
        start_date=planning_date,
        end_date=planning_date + timedelta(days=1),
    )
    dose_id = doses[0]["id"]

    read_response = client.get(
        f"/medication-calendar/patients/{seeded_access_context['patient'].id}/planning/today",
        params={"planning_date": planning_date.isoformat()},
        headers=seeded_access_context["family_viewer_headers"],
    )
    assert read_response.status_code == 200, read_response.text

    viewer_take_response = client.post(
        f"/medication-calendar/scheduled-doses/{dose_id}/take",
        json={},
        headers=seeded_access_context["family_viewer_headers"],
    )
    assert viewer_take_response.status_code == 403

    admin_take_response = client.post(
        f"/medication-calendar/scheduled-doses/{dose_id}/take",
        json={},
        headers=seeded_access_context["family_admin_headers"],
    )
    assert admin_take_response.status_code == 200, admin_take_response.text
