---
trigger: glob
globs: "*.ts, *.tsx, *.jsx, *.html, *.css"
description: "React 19, TypeScript, Tailwind ve modern Web frontend kuralları"
---
# Frontend (Web / React / Angular / TypeScript) Kuralları
- **React 19 & State Yönetimi**: Gereksiz `useEffect` kullanımından kaçın; hesaplanabilir değerleri türetilmiş state (derived state) veya pure function ile yönet.
- **Tip Güvenliği**: Strict typing zorunludur; `any` kullanımı kesinlikle yasaktır (`unknown` veya açık TypeScript interface/type kullan). Backend kontratlarına %100 uyan strict DTO tipleri tanımla.
- **Tailwind CSS**: Tutarlı spacing, typography ve semantic renk sınıflarını kullan; inline arbitrary style'lardan kaçın.
- **Modern Angular Projeleri**: Angular içeren modüllerde Standalone component mimarisi, Signals (`signal`, `computed`, `effect`), `ChangeDetectionStrategy.OnPush` ve yeni control flow (`@if`, `@for`) sözdizimini kullan.
- **Bellek ve Yan Etki Yönetimi**: Event listener, interval ve aboneliklerin unmount/destroy anında eksiksiz temizlendiğinden (cleanup) emin ol.
