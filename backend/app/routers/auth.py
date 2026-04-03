from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, models, schemas
from ..deps import get_current_user, get_db
from ..security import create_access_token, verify_password

router = APIRouter()


def _build_token_response(user: models.User) -> schemas.Token:
    token = create_access_token(subject=str(user.id), role=user.role)
    return schemas.Token(
        access_token=token,
        role=user.role,
        user_id=user.id,
        user=schemas.TokenUser.model_validate(user),
    )


def _ensure_unique_user_identity(db: Session, cin: str, email: str) -> None:
    if cruds.get_user_by_cin(db, cin):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="CIN already exists",
        )
    if cruds.get_user_by_email(db, email):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already exists",
        )


def _create_doctor(db: Session, payload: schemas.RegisterDoctorRequest) -> models.User:
    _ensure_unique_user_identity(db, payload.cin, payload.email)
    return cruds.create_user(
        db=db,
        first_name=payload.first_name,
        last_name=payload.last_name,
        cin=payload.cin,
        email=payload.email,
        password=payload.password,
        role="doctor",
    )


def _create_family(db: Session, payload: schemas.RegisterFamilyRequest) -> models.User:
    _ensure_unique_user_identity(db, payload.cin, payload.email)

    patient = cruds.get_patient_by_cin(db, payload.patient_cin)
    if patient is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found for the provided patient_cin",
        )

    if payload.family_role == "admin":
        existing_admin = cruds.get_family_admin_link(db, patient.id)
        if existing_admin is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An admin already exists for this patient",
            )

    # Create user + link in one transaction to avoid partial writes.
    try:
        user = cruds.create_user(
            db=db,
            first_name=payload.first_name,
            last_name=payload.last_name,
            cin=payload.cin,
            email=payload.email,
            password=payload.password,
            role="family",
            commit=False,
        )
        cruds.link_family_to_patient(
            db=db,
            user_id=user.id,
            patient_id=patient.id,
            family_role=payload.family_role,
            relation_to_patient=payload.relation_to_patient,
            commit=False,
        )
        db.commit()
        db.refresh(user)
        return user
    except cruds.AdminConflictError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An admin already exists for this patient",
        ) from None
    except cruds.RoleConstraintError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from None
    except cruds.BusinessRuleError as exc:
        db.rollback()
        status_code = (
            status.HTTP_404_NOT_FOUND
            if str(exc) == "Patient not found"
            else status.HTTP_400_BAD_REQUEST
        )
        raise HTTPException(
            status_code=status_code,
            detail=str(exc),
        ) from None
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Family registration conflict",
        ) from None


@router.post("/register-doctor", response_model=schemas.User, status_code=status.HTTP_201_CREATED)
def register_doctor(
    payload: schemas.RegisterDoctorRequest,
    db: Session = Depends(get_db),
):
    try:
        return _create_doctor(db, payload)
    except cruds.BusinessRuleError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Doctor registration conflict",
        ) from None


@router.post("/register-family", response_model=schemas.User, status_code=status.HTTP_201_CREATED)
def register_family(
    payload: schemas.RegisterFamilyRequest,
    db: Session = Depends(get_db),
):
    return _create_family(db, payload)


@router.post(
    "/register",
    response_model=schemas.User,
    status_code=status.HTTP_201_CREATED,
    deprecated=True,
)
def register_user_compat(
    payload: schemas.RegisterLegacyRequest,
    db: Session = Depends(get_db),
):
    if payload.role == "doctor":
        doctor_payload = schemas.RegisterDoctorRequest(
            first_name=payload.first_name,
            last_name=payload.last_name,
            cin=payload.cin,
            email=payload.email,
            password=payload.password,
        )
        try:
            return _create_doctor(db, doctor_payload)
        except cruds.BusinessRuleError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(exc),
            ) from None
        except IntegrityError:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Doctor registration conflict",
            ) from None

    if not payload.patient_cin:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="patient_cin is required when role='family'",
        )
    if not payload.family_role:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="family_role is required when role='family'",
        )
    if not payload.relation_to_patient:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="relation_to_patient is required when role='family'",
        )

    family_payload = schemas.RegisterFamilyRequest(
        first_name=payload.first_name,
        last_name=payload.last_name,
        cin=payload.cin,
        email=payload.email,
        password=payload.password,
        patient_cin=payload.patient_cin,
        family_role=payload.family_role,
        relation_to_patient=payload.relation_to_patient,
    )
    return _create_family(db, family_payload)


@router.post("/login", response_model=schemas.Token)
def login(payload: schemas.LoginRequest, db: Session = Depends(get_db)):
    user = cruds.get_user_by_cin(db, payload.cin)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found with this CIN",
        )

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid CIN or password",
        )

    return _build_token_response(user)


@router.get("/me", response_model=schemas.User)
def get_me(current_user=Depends(get_current_user)):
    return current_user
