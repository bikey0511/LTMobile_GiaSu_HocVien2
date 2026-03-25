# 📚 Tutor – Student Matching Platform (Flutter)

A full-featured cross-platform mobile application that connects tutors and students, supporting booking, real-time chat, online classes, and QR-based payment system.

---

## 🚀 Features

### 🔐 Authentication & Authorization
- Sign up / Login with Email & Password
- Google OAuth login
- Role-based access control (Admin / Tutor / Student)

### 📅 Booking & Class Management
- Create, accept, reject bookings
- Track class status and history
- Support multi-session classes

### 💬 Real-time Chat
- 1-1 and group chat using Firebase Firestore
- Message history storage
- Real-time updates

### 🎥 Online Video Class
- Integrated video call using Jitsi Meet

### 💰 Wallet & QR Payment System
- Users top up balance via **QR bank transfer**
- Upload payment proof (image)
- Admin verifies transaction manually
- Update user wallet after approval
- Transaction status:
  - Pending
  - Approved
  - Rejected

### ⭐ Reviews & Ratings
- Users can rate tutors (1–5 stars)
- Feedback and comments system

### 📂 File & Image Management
- Upload images/files using Firebase Storage
- Optimized image storage with Cloudinary

### 🌐 Other Features
- Localization (Vietnamese / English)
- Responsive UI (multiple screen sizes)
- Push notifications (Firebase Cloud Messaging)

---

## 🛠 Tech Stack

- **Flutter, Dart**
- **Firebase (Auth, Firestore,)**
- Provider (State Management)
- REST API (HTTP, JSON)
- Jitsi Meet (Video Call)
- VietQr
- Cloudinary (Image Optimization)
- Git

---

## 🧠 Architecture

- Provider Pattern (State Management)
- Repository Pattern (Data Layer Separation)
- Scalable and maintainable structure

---


## ⚙️ Installation

```bash
git clone https://github.com/bikey0511/tutor-student-flutter-app.git
cd tutor-student-flutter-app
flutter pub get
flutter run
