# schemas/notification.py
from pydantic import BaseModel, ConfigDict, field_validator
from typing import Optional, List
from datetime import datetime
import uuid


class NotificationBase(BaseModel):
    type: str
    title: str
    message: str
    scheduled_date: Optional[datetime] = None
    action_url: Optional[str] = None


class NotificationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    subscription_id: int
    type: str
    title: str
    message: str
    scheduled_date: Optional[datetime] = None
    sent_at: Optional[datetime] = None
    read: bool
    action_url: Optional[str] = None
    created_at: datetime

    #Добавляем валидатор для безопасного преобразования
    @field_validator('id', 'user_id', mode='before')
    @classmethod
    def convert_to_string(cls, v):
        if isinstance(v, uuid.UUID):
            return str(v)
        # Если уже строка, оставляем как есть
        if isinstance(v, str):
            return v
        # Для любых других типов преобразуем в строку
        return str(v)


class NotificationGroup(BaseModel):
    subscription_id: int
    subscription_name: str
    subscription_amount: float
    subscription_category: Optional[str] = None
    notifications: List[NotificationResponse]
    unread_count: int
    last_notification_date: Optional[datetime] = None


class NotificationReadRequest(BaseModel):
    read: bool = True


class ReadAllResponse(BaseModel):
    message: str
    count: int