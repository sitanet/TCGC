# Notification System - Backend API Requirements

## Overview
This document outlines the backend API endpoints required for the TCGC app notification system.

## Required Endpoints

### 1. Device Registration

**Register Device Token**
```
POST /api/devices/register/
Authorization: Bearer <access_token>
Content-Type: application/json

Request:
{
  "token": "fcm_device_token_string",
  "platform": "android" | "ios"
}

Response (201):
{
  "id": 1,
  "token": "fcm_device_token_string",
  "platform": "android",
  "created_at": "2025-12-31T10:00:00Z"
}
```

**Unregister Device Token**
```
POST /api/devices/unregister/
Authorization: Bearer <access_token>
Content-Type: application/json

Request:
{
  "token": "fcm_device_token_string"
}

Response (204): No Content
```

### 2. Notifications

**Get Notifications**
```
GET /api/notifications/
Authorization: Bearer <access_token>

Response (200):
[
  {
    "id": 1,
    "title": "New Sermon Available",
    "body": "Pastor John's latest message is now available",
    "image_url": "https://...",
    "type": "sermon",
    "data": {"sermon_id": 123},
    "is_read": false,
    "created_at": "2025-12-31T10:00:00Z"
  }
]
```

**Mark Notification as Read**
```
POST /api/notifications/read/{notification_id}/
Authorization: Bearer <access_token>

Response (200):
{
  "id": 1,
  "is_read": true
}
```

**Mark All Notifications as Read**
```
POST /api/notifications/read-all/
Authorization: Bearer <access_token>

Response (200):
{
  "message": "All notifications marked as read",
  "count": 5
}
```

### 3. Notification Preferences

**Get/Update Preferences**
```
GET/PATCH /api/notifications/preferences/
Authorization: Bearer <access_token>
Content-Type: application/json

Request (PATCH):
{
  "push_enabled": true,
  "email_enabled": true,
  "sms_enabled": false,
  "events_enabled": true,
  "sermons_enabled": true,
  "wallet_enabled": true
}

Response (200):
{
  "push_enabled": true,
  "email_enabled": true,
  "sms_enabled": false,
  "events_enabled": true,
  "sermons_enabled": true,
  "wallet_enabled": true
}
```

## Notification Types
- `general` - General announcements
- `event` - Event notifications
- `sermon` - New sermon/message notifications
- `wallet` - Wallet/transaction notifications
- `live` - Live stream notifications

## Firebase Cloud Messaging (FCM) Setup

### Backend Requirements
1. Add Firebase Admin SDK to your Django project
2. Store FCM server key in environment variables
3. Create a service to send push notifications

### Django Example (using `fcm-django`):
```python
# Install: pip install fcm-django

# settings.py
FCM_DJANGO_SETTINGS = {
    "FCM_SERVER_KEY": env("FCM_SERVER_KEY"),
}

# Send notification example
from fcm_django.models import FCMDevice

def send_push_notification(user_id, title, body, data=None):
    devices = FCMDevice.objects.filter(user_id=user_id, active=True)
    devices.send_message(
        title=title,
        body=body,
        data=data or {}
    )
```

## Admin Panel Features Needed
1. Send push notifications to all users or segments
2. Schedule notifications for future delivery
3. View notification delivery statistics
4. Manage notification templates
5. User notification history view

## Database Models

### Device Model
```python
class Device(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    token = models.CharField(max_length=255, unique=True)
    platform = models.CharField(max_length=10)  # 'android' or 'ios'
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
```

### Notification Model
```python
class Notification(models.Model):
    TYPES = [
        ('general', 'General'),
        ('event', 'Event'),
        ('sermon', 'Sermon'),
        ('wallet', 'Wallet'),
        ('live', 'Live Stream'),
    ]
    
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    title = models.CharField(max_length=255)
    body = models.TextField()
    image_url = models.URLField(blank=True, null=True)
    type = models.CharField(max_length=20, choices=TYPES, default='general')
    data = models.JSONField(default=dict, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
```

### NotificationPreferences Model
```python
class NotificationPreferences(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    push_enabled = models.BooleanField(default=True)
    email_enabled = models.BooleanField(default=True)
    sms_enabled = models.BooleanField(default=False)
    events_enabled = models.BooleanField(default=True)
    sermons_enabled = models.BooleanField(default=True)
    wallet_enabled = models.BooleanField(default=True)
```
