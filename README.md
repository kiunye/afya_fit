# Afya Fit

A comprehensive fitness training platform that connects trainers with their clients, enabling workout plan management, nutrition tracking, progress monitoring, and subscription-based billing.

## Overview

Afya Fit is a full-stack application consisting of:

- **Backend API**: Phoenix (Elixir) web application providing RESTful APIs and admin dashboard
- **Mobile App**: Flutter (Dart) cross-platform mobile application for trainers and clients

## Key Features

### For Trainers
- Client management and relationship tracking
- Workout plan creation and assignment
- Nutrition plan management
- Progress tracking and analytics
- Task management and automation
- Calendar and event scheduling
- Subscription billing and payment processing (Paystack integration)
- Admin dashboard for platform management

### For Clients
- View assigned workout and nutrition plans
- Track personal progress with measurements and photos
- Complete assigned tasks
- Manage subscription and billing

### Platform Features
- User authentication and authorization
- Role-based access control (Admin, Trainer, Client)
- Subscription management with automated reminders
- Email notifications and reminders
- Activity logging
- API-first architecture for mobile integration

## Tech Stack

### Backend
- **Framework**: Phoenix 1.8
- **Language**: Elixir
- **Database**: PostgreSQL with Row-Level Security (RLS)
- **Background Jobs**: Oban
- **Email**: Swoosh
- **Payments**: Paystack integration
- **UI**: Phoenix LiveView with Tailwind CSS

### Mobile
- **Framework**: Flutter
- **State Management**: Riverpod 3.0 with code generation
- **Architecture**: Feature-first with clean architecture principles
- **Networking**: HTTP client with token-based authentication

## Getting Started

### Backend Setup

1. Install dependencies:
   ```bash
   mix setup
   ```

2. Start the Phoenix server:
   ```bash
   mix phx.server
   ```
   Or inside IEx:
   ```bash
   iex -S mix phx.server
   ```

3. Visit [`localhost:4000`](http://localhost:4000) in your browser

### Mobile App Setup

1. Navigate to the Flutter app directory:
   ```bash
   cd afya_fit
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Generate code (Riverpod providers, JSON serialization):
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
.
├── lib/                    # Phoenix backend
│   ├── afya_fit/          # Domain contexts (Accounts, Billing, Workouts, etc.)
│   └── afya_fit_web/      # Web layer (Controllers, LiveViews, Router)
├── afya_fit/              # Flutter mobile app
│   └── lib/
│       ├── core/          # Core infrastructure
│       ├── features/      # Feature modules (auth, workouts, nutrition, etc.)
│       └── shared/       # Shared components
└── priv/repo/migrations/  # Database migrations
```

## Learn More

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod Documentation](https://riverpod.dev/)
