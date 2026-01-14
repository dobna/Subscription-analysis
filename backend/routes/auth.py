from fastapi import APIRouter, Depends, HTTPException, status, Security, Request
from sqlalchemy.orm import Session
from backend.database import SessionLocal
from backend.models.user import User
from backend.utils.security import  hash_password, verify_password, create_access_token, create_refresh_token,decode_refresh_token, decode_token
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer, OAuth2PasswordRequestForm
from ..schemas.user import UserRegister, UserLogin
from backend.models.notification import Notification
from backend.database import get_db
security = HTTPBearer()

router = APIRouter(
    prefix="/api",
    tags=["auth"]
)
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24
REFRESH_TOKEN_EXPIRE_DAYS = 7
SECRET_KEY =  'af1684b7f8df00a7d0abf58e3ac0c5d905cf804885b329e9ed08571b44204869'  # для access токенов
REFRESH_SECRET_KEY =  '9ad70b9831981bb6564e94c7b79e2756fe7d0a795b712acd4facbc6157b83cba'  # для refresh токенов
ALGORITHM = "HS256"

@router.post("/register")
def register(user: UserRegister, db: Session = Depends(get_db)):
    # Проверяем существование пользователя
    existing_user = db.query(User).filter(User.email == user.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Registration failed"
        )

    # Пароль не должен содержать email
    email_local_part = user.email.split('@')[0].lower()
    if email_local_part in user.password.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password should not contain your email"
        )

    # Дополнительная проверка: пароль не равен email
    if user.password.lower() == user.email.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password cannot be the same as email"
        )

    # Хэшируем пароль и создаем пользователя
    new_user = User(
        email=user.email,
        password=hash_password(user.password)
    )

    try:
        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        return {
            "message": "User registered successfully",
            "user_id": new_user.id,
            "email": new_user.email
        }

    except Exception as e:
        db.rollback()
        import logging
        logger = logging.getLogger(__name__)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed, please try again"
        )

@router.post("/login")
def login(data: UserLogin, db: Session = Depends(get_db)):
    db.expire_all()

    all_users = db.query(User).all()

    from sqlalchemy import text
    try:
        sql_result = db.execute(
            text("SELECT id, email, password FROM users WHERE email = :email"),
            {"email": data.email}
        ).first()
    except Exception as e:
        print(f"Raw SQL error: {e}")

    # 4. ORM запрос (может быть закешировано)
    user = db.query(User).filter(User.email == data.email).first()

    if user:
        is_password_valid = verify_password(data.password, user.password)

        if not is_password_valid:
            raise HTTPException(status_code=400, detail="Invalid email or password")
    else:
        raise HTTPException(status_code=400, detail="Invalid email or password")

    try:
        access_token = create_access_token(
            data={"user_id": user.id},
            expires_minutes=ACCESS_TOKEN_EXPIRE_MINUTES
        )

        refresh_token = create_refresh_token(
            data={"user_id": user.id, "type": "refresh"},
            expires_days=REFRESH_TOKEN_EXPIRE_DAYS
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail="Token creation failed")

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60,  # в секундах для фронтенда
        "user_id": user.id,
        "message": "Login successful"
    }

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    token = credentials.credentials
    payload = decode_token(token)

    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )

    user = db.query(User).filter(User.id == payload["user_id"]).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return user

@router.get("/profile")
def get_profile(credentials: HTTPAuthorizationCredentials = Depends(security),
                db: Session = Depends(get_db)):

    token = credentials.credentials
    payload = decode_token(token)

    if payload is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    user = db.query(User).filter(User.id == payload["user_id"]).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return {"id": user.id, "email": user.email}



@router.post("/logout")
def logout():
    return {"message": "Logged out (token removed on client side)"}

@router.get("/me")
def get_me(user: User = Depends(get_current_user)):
    return {"id": user.id, "email": user.email}


@router.post("/test-validation")
async def test_validation(request: Request):
    try:
        raw_data = await request.json()

        user = UserRegister(**raw_data)

        return {
            "success": True,
            "message": "Validation passed",
            "data": {
                "email": user.email,
                "password_length": len(user.password),
                "confirm_password_length": len(user.confirm_password)
            }
        }

    except Exception as e:
        import traceback
        traceback.print_exc()

        return {
            "success": False,
            "error": str(e),
            "type": type(e).__name__,
            "raw_data": raw_data
        }