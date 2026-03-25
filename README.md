# 📚 Tutor – Student Matching Platform (Flutter)

A full-featured mobile application that connects tutors and students, supporting booking, real-time chat, and online learning.

---

## 🚀 Features

### 🔐 Authentication & Authorization
- Sign up / Login (Email & Password, Google OAuth)
- Role-based access control (Admin / Tutor / Student)

### 📅 Booking System
- Create, accept/reject bookings
- Track class status and history

### 💬 Real-time Chat
- 1-1 and group chat using Firebase Firestore
- Message history storage

### 🎥 Video Call
- Integrated online class via Jitsi Meet

### 💰 Wallet & Payment
- QR-based payment flow
- Users upload payment proof
- Admin verifies and updates balance
- Transaction status: pending / approved / rejected

### 🌐 Other Features
- Localization (Vietnamese / English)
- Responsive UI
- State management with Provider

---

## 🛠 Tech Stack

- **Flutter, Dart**
- **Firebase (Auth, Firestore, Storage)**
- Provider (State Management)
- REST API
- Jitsi Meet (Video Call)
- Git

---

## 🧠 Architecture

- Provider Pattern (State Management)
- Repository Pattern (Data Layer)

---


## ⚙️ Installation

```bash
git clone https://github.com/bikey0511/tutor-student-flutter-app.git
cd tutor-student-flutter-app
flutter pub get
flutter run
