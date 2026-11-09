---
description: React, Next.js & TypeScript Frontend Rules
globs: "*.ts, *.tsx, *.js, *.jsx, *.html, *.css"
alwaysApply: false
---
# Frontend (Web / React / Next.js / TypeScript) Rules
- **React 19 & State Management**: Avoid unnecessary `useEffect` hooks; manage computable values via derived state or pure functions.
- **Type Safety**: Strict typing is mandatory; `any` is strictly prohibited (use `unknown` or explicit TypeScript interfaces/types). Define strict DTO types that match backend contracts 100%.
- **Tailwind CSS**: Use consistent spacing, typography, and semantic color classes; avoid inline arbitrary styles where design tokens exist.
- **Modern Angular Projects**: For Angular modules, follow Standalone component architecture, Signals (`signal`, `computed`, `effect`), `ChangeDetectionStrategy.OnPush`, and new control flow syntax (`@if`, `@for`).
- **Memory & Lifecycle Management**: Ensure event listeners, intervals, and subscriptions are completely cleaned up on component unmount or destruction.
