# Project Instincts & Architectural Decisions (Example Template)

- **[Clean-Architecture-Boundaries]** (Initial): Dependencies between layers must always flow inward (Domain <- Application <- Infrastructure / UI). The Domain and Application layers must remain free of external libraries and concrete infrastructure dependencies.
- **[EF-Core-Read-Performance]** (Initial): Read-only database queries must use `.AsNoTracking()`, and all asynchronous methods must accept and propagate a `CancellationToken`. Avoid N+1 queries by leveraging projection (`Select`) or targeted `Include`.
- **[Strict-Frontend-Typing]** (Initial): The `any` type is strictly forbidden in frontend codebases (TypeScript); all API responses, component props, and state objects must be explicitly typed using interfaces or types.
- **[Flutter-Const-And-Isolation]** (Initial): Use `const` constructors wherever possible in Flutter widget trees to minimize re-renders; keep state management isolated from business logic.
- **[Ponytail-Minimalism]** (Initial): Prioritize existing platform libraries and codebase patterns; never introduce unnecessary third-party packages or single-use abstractions (Interface/Factory) for a few lines of logic.
