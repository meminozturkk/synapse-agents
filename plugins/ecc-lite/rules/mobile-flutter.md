---
description: Flutter & Dart Mobile Engineering Rules
globs: "*.dart, pubspec.yaml"
alwaysApply: false
---
# Mobile (Flutter / Dart) Rules
- **Folder Structure**: Follow a feature-first directory layout and preserve layer separation (presentation, domain, data).
- **Performance**: Use `const` constructors wherever possible to prevent unnecessary rebuilds in the widget tree; decompose large widgets into smaller subcomponents.
- **State & Lifecycle Management**: Enforce immutable state; never use `BuildContext` across asynchronous gaps without checking `if (!context.mounted) return;`.
