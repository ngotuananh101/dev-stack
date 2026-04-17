# Project Context: Ponta App (Windows)

## Overview
This is a Flutter Windows desktop application project initialized with Riverpod for state management.

## Tech Stack
- **Framework**: Flutter
- **State Management**: [Riverpod](https://riverpod.dev) (Modern Generator approach)
- **Database**: [Isar](https://isar.dev) (高性能 NoSQL)
- **Code Generation**: `riverpod_generator`, `isar_generator`, `build_runner`

## Key Architecture Decisions
- **UI Architecture**: Separated into `core/theme`, `shared/widgets`, `shared/layouts`, and `features`.
- **Provider Definition**: Providers are defined using the `@riverpod` annotation.
- **Consumer Usage**: UI components use `ConsumerWidget` to access state.
- **Code Generation**: Handled by `build_runner`.

## Project Structure
- `lib/core/theme`: Design tokens, colors, and global theme.
- `lib/core/database`: Isar database initialization and providers.
- `lib/shared/widgets`: Atomic components (Button, Card, StatusChip).
- `lib/shared/layouts`: Structural templates (Sidebar, Layout).
- `lib/features`: Business logic and feature-specific UI (Dashboard, Hosts).
- `lib/shared/providers`: Global state providers (Navigation).

## Key Files
- `lib/main.dart`: Root of the application and shell navigation.
- `lib/features/dashboard`: System monitoring feature.
- `lib/features/hosts`: Windows hosts file management.
- `lib/features/dashboard/widgets`: Feature-specific components (MemoryCard, StorageCard, StatCard).

## Commands
- **Install Dependencies**: `flutter pub get`
- **Watch/Generate Code**: `dart run build_runner watch --delete-conflicting-outputs`
- **One-time Build**: `dart run build_runner build --delete-conflicting-outputs`
- **Run Project**: `flutter run`
