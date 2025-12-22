# Afya Fit Mobile App

Flutter mobile application for Afya Fit - a fitness training platform for trainers and clients.

## Project Structure

The project follows a **feature-first architecture** with clear separation of concerns:

```
lib/
├── core/                    # Core infrastructure
│   ├── api/                # API client and networking
│   ├── constants/          # App-wide constants
│   ├── providers/          # Core Riverpod providers
│   └── utils/              # Utility functions and themes
│
├── features/               # Feature modules
│   ├── auth/              # Authentication feature
│   │   ├── data/
│   │   │   ├── models/    # Data models
│   │   │   └── repositories/  # Data layer
│   │   ├── domain/
│   │   │   └── use_cases/  # Business logic
│   │   ├── presentation/
│   │   │   ├── screens/   # UI screens
│   │   │   └── widgets/   # Reusable widgets
│   │   └── providers/     # Feature-specific providers
│   │
│   ├── workouts/           # Workout management
│   ├── nutrition/          # Nutrition plans
│   ├── progress/          # Progress tracking
│   └── tasks/             # Task management
│
└── shared/                 # Shared components
    ├── models/            # Shared models
    └── widgets/           # Shared widgets
```

## State Management

The app uses **Riverpod 3.0** with code generation for type-safe state management:

- **ConsumerWidget** / **HookConsumerWidget** for UI components
- **@riverpod** annotations for provider generation
- Repository pattern for data access
- Use cases for business logic

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Dart SDK 3.10.1+

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Generate code (Riverpod providers, JSON serialization):
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

3. Run the app:
```bash
flutter run
```

### Development

For continuous code generation during development:
```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

## API Configuration

The app connects to the Phoenix backend API. The base URL is automatically configured based on the platform:
- **Android Emulator**: Uses `http://10.0.2.2:4000` (special IP to access host machine)
- **iOS Simulator**: Uses `http://localhost:4000`
- **Physical Devices**: You'll need to update `lib/core/constants/api_constants.dart` to use your machine's IP address (e.g., `http://192.168.1.100:4000`)

The configuration is in `lib/core/constants/api_constants.dart` and automatically detects the platform.

## Phase 8 Implementation Status

- [x] Initialize Flutter project (latest version)
- [x] Set up Riverpod state management baseline (flutter_riverpod + hooks_riverpod)
- [x] Add Riverpod codegen tooling (riverpod_annotation, riverpod_generator, build_runner)
- [x] Define feature-first structure (auth/workouts/nutrition/progress/tasks) with repositories/use-cases exposed via providers
- [x] Standardize UI layer on ConsumerWidget / HookConsumerWidget
- [x] Authentication flow (login, logout, auth guard)
- [x] Dashboard views (stats, quick actions, recent activity)
- [x] Workout/nutrition viewing (list screens with cards)
- [x] Progress tracking (entries list with metrics)
- [x] Task completion (task list with completion functionality)
- [x] Navigation routing (app router with named routes)

## Dependencies

### Core
- `flutter_riverpod: ^3.0.3` - State management
- `hooks_riverpod: ^3.0.3` - Riverpod with hooks
- `riverpod_annotation: ^3.0.3` - Provider annotations
- `http: ^1.2.2` - HTTP client
- `shared_preferences: ^2.3.2` - Local storage
- `flutter_hooks: ^0.21.3` - Flutter hooks

### Code Generation
- `build_runner: ^2.10.4` - Code generation runner
- `riverpod_generator: ^3.0.3` - Riverpod code generator
- `json_serializable: ^6.11.2` - JSON serialization

### Utilities
- `intl: ^0.19.0` - Internationalization and date formatting

## Architecture Guidelines

1. **Always use ConsumerWidget or HookConsumerWidget** - Never use StatefulWidget for state management
2. **Repositories handle data access** - All API calls go through repositories
3. **Use cases contain business logic** - Keep repositories focused on data operations
4. **Providers expose repositories and use cases** - Use Riverpod code generation
5. **Models use JSON serialization** - Use `@JsonSerializable` for all models
6. **Navigation** - Use named routes via `AppRouter` for consistent navigation

## Features Implemented

### Authentication
- Login screen with form validation
- Auth provider with token management
- Auth guard for protected routes
- Logout functionality

### Dashboard
- Statistics cards (clients, workouts, nutrition, tasks, events)
- Quick action buttons with navigation
- Recent clients and workouts sections
- Pull-to-refresh functionality

### Workouts
- Workout plans list with cards
- Difficulty indicators
- Duration display
- Empty and error states

### Nutrition
- Nutrition plans list
- Daily calories display
- Empty and error states

### Progress Tracking
- Progress entries list
- Weight and body fat metrics
- Date formatting
- Client-specific progress

### Tasks
- Task list with pending/completed sections
- Task completion functionality
- Priority indicators (high/medium/low)
- Due date display

## Next Steps

- Create/edit forms for workouts, nutrition, progress, and tasks
- Detail screens for viewing full information
- Client management screens
- Bottom navigation bar for easier navigation
- Search and filtering functionality
