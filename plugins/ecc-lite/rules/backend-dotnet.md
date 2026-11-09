---
description: .NET 9 & Clean Architecture Rules
globs: "*.cs, *.csproj, *.sln"
alwaysApply: false
---
# Backend (.NET 9 / C#) Rules
- **Architecture**: Preserve Clean Architecture and CQRS layer boundaries; never leak external dependencies or concrete infrastructure into the Domain layer.
- **Asynchronous Programming**: Always use `async/await` for all I/O and database operations, and enforce passing the `CancellationToken` parameter down the call chain.
- **EF Core Performance**: Always use `.AsNoTracking()` for read-only queries; avoid N+1 queries by leveraging projection (`Select`) or targeted `Include`.
- **Dependency Injection**: Prevent captive dependencies (never inject Scoped services into a Singleton).
- **Error Handling**: Use the Result pattern or domain-specific exceptions instead of throwing generic exceptions for business rule violations.
