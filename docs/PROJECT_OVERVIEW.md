# FOORA – Project Overview

## 1. Project Overview

**FOORA** is a mobile application for household food tracking and expiration management.

The application helps users:

- Manage food currently available at home
- Track food quantities
- Track expiration dates
- Receive expiration reminders
- Identify food that should be consumed first
- Reduce duplicate purchases
- Reduce food waste
- Make better food consumption and shopping decisions

FOORA is designed to evolve into an **AI-powered personal and household food assistant**.

---

## 2. Project Objectives

The main objectives of FOORA are:

1. Reduce household food waste.
2. Help users track food inventory easily.
3. Track food quantities and expiration dates.
4. Remind users before food expires.
5. Reduce duplicate food purchases.
6. Simplify household food management.
7. Support smarter food consumption and shopping decisions.

---

## 3. Target Users

### Primary Users

- Families living in cities
- Families who regularly purchase food
- Families who want to reduce food waste
- Families who want to manage household expenses more effectively

### Secondary Users

- Working professionals aged 22–35
- Students living independently
- People who frequently buy and stockpile food
- People interested in reducing food waste

---

## 4. User Roles

### Guest

Guests can:

- Register
- Login
- View membership information

### Free Member

Free members can:

- Manage food inventory with limitations
- Track expiration dates
- Receive notifications
- Use AI features with limitations

### Premium Member

Premium members can:

- Access all Free features
- Use extended AI features
- Access a higher AI usage quota

### Admin

Admins can:

- Manage users
- Manage memberships
- Manage AI usage
- Manage shelf-life rules
- Manage payments
- View system statistics

---

## 5. MVP Features

### 5.1 Authentication & Profile

- Register
- Login
- Logout
- Profile management
- Password management

Authentication is handled by **Firebase Authentication**.

---

### 5.2 Membership

The application provides:

- Free Plan
- Premium Plan

Members can:

- View memberships
- View current membership status
- Upgrade membership
- View AI usage quota

Admins can configure:

- Membership price
- Membership duration
- AI usage quota

---

### 5.3 Food Inventory

Members can:

- Add food
- Edit food
- Delete food
- View food inventory
- Update quantity
- Select unit
- Select category
- Select storage location

MVP storage locations:

- Refrigerator
- Freezer

---

### 5.4 Food Input

FOORA supports two food input methods:

1. Manual Form
2. Receipt Scanning

Receipt scanning uses OCR to extract:

- Food name
- Quantity
- Unit
- Vietnamese text
- Vietnamese text without diacritics

OCR output is processed and normalized before being used to update the inventory.

---

### 5.5 Expiration Management

FOORA tracks:

- Expiration date
- Expiration status
- Remaining shelf life
- Expiring food
- Expired food
- Priority food

MVP shelf-life recommendation uses a **rule-based approach**.

Rules consider:

- Food type
- Storage location
- Storage condition
- Shelf-life rules

Shelf-life rules are stored in Firestore.

---

### 5.6 Smart Inventory

FOORA can help users:

- Check whether food already exists
- Check remaining quantity
- Check expiration status
- Find food in inventory
- Identify food that should be consumed first
- Reduce duplicate purchases

Inventory batches should be kept separately when their expiration dates differ.

Example:

```text
Tomato
├── Batch A
│   ├── Quantity: 3
│   └── Expiration: 2026-08-28
│
└── Batch B
    ├── Quantity: 5
    └── Expiration: 2026-09-03
```

When consuming food, the system should prioritize the batch with the earliest expiration date.

This follows the **FEFO (First Expired, First Out)** concept.

---

### 5.7 Notifications

MVP notification types:

- Expiration alerts
- Upcoming expiration reminders
- Priority food reminders
- System notifications

Notifications are delivered using **Firebase Cloud Messaging**.

---

### 5.8 Dashboard

The Home dashboard provides:

- Inventory Summary Data
- Top priority items
- Expiring soon Data
- Recent Data

---

## 6. AI Features

AI is used to support intelligent food management.

MVP AI capabilities include:

- Receipt information processing
- Food name normalization
- Smart inventory analysis
- Natural-language inventory queries

Future AI capabilities may include:

- Recipe recommendations
- Menu recommendations
- Smart shopping recommendations
- Voice-based inventory queries
- Voice-based inventory updates

AI food recognition from food images is **not part of the current core MVP**.

---

## 7. AI Assistant

FOORA is designed to support natural-language interaction with the member's food inventory.

Example operations:

- Check food quantity
- Check expiration status
- Find food
- Update food quantity
- Find food that should be consumed first
- Recommend food to consume

Basic flow:

```text
User Voice
    ↓
Speech-to-Text
    ↓
Text Prompt
    ↓
Gemini
    ↓
Intent Understanding
    ↓
Query / Update Firebase
    ↓
Response
```

The AI Assistant should not directly access Firestore from the client.

AI-related operations should be handled through the appropriate backend layer.

---

## 8. Technology Stack

### Frontend

- Flutter
- Dart

### Backend / Cloud

- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Functions
- Firebase Cloud Messaging
- Firebase Emulator Suite

### AI

- Gemini API

### OCR

- Google ML Kit Text Recognition

### Voice

- Speech-to-Text

### Deployment

- Android → Google Play
- iOS → App Store
- Admin Web → Firebase Hosting
- Backend → Firebase

---

## 9. Database

FOORA uses **Cloud Firestore** as its primary database.

Main collections:

```text
users
households
memberships
foods
food_categories
storage_locations
shelf_life_rules
```

Household-specific subcollections:

```text
households/{householdId}/inventory_items
```

User-specific subcollections:

```text
users/{userId}/subscriptions
users/{userId}/payments
users/{userId}/receipts
users/{userId}/notifications
users/{userId}/devices
users/{userId}/ai_usage
```

---

## 10. Architecture

FOORA uses:

**Feature-Based Clean Architecture**

The project is organized by business feature.

Each major feature separates:

- Data layer
- Domain layer
- Presentation layer

Example:

```text
Feature
├── data
├── domain
└── presentation
```

The architecture is designed to keep business logic independent from UI and external data sources.

---

## 11. Development Principles

When implementing FOORA:

- Follow Feature-Based Clean Architecture.
- Keep business logic inside the domain layer.
- Keep Firebase implementation inside data/data-source layers.
- Do not access Firestore directly from UI widgets.
- Use repositories as the abstraction between domain and data.
- Keep Firebase models separate from domain entities.
- Use Cloud Functions for trusted server-side operations.
- Validate important operations on the backend.
- Do not store passwords in Firestore.
- Avoid duplicating food master data unnecessarily.
- Keep inventory batches separate when expiration dates differ.
- Do not hard-code membership configuration that should be managed by Admin.

---

## 12. MVP Scope

The initial MVP focuses on:

```text
Authentication
      ↓
Profile
      ↓
Food Inventory
      ↓
Expiration Tracking
      ↓
Notifications
      ↓
Receipt OCR
      ↓
Food Normalization
      ↓
Limited AI
      ↓
Free / Premium Membership
```

Features outside the core MVP should not be implemented unless they are explicitly added to the project scope.
