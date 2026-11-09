---
trigger: glob
globs: "*.cs, *.csproj, *.sln"
description: ".NET Core, C#, EF Core ve Clean Architecture kuralları"
---
# Backend (.NET / C#) Kuralları
- **Mimari**: Clean Architecture ve CQRS katman sınırlarını koru; Domain katmanına dış bağımlılık ekleme.
- **Asenkron Programlama**: Tüm I/O ve veritabanı metotlarında `async/await` kullan ve `CancellationToken` parametresini zorunlu olarak aşağıya ilet.
- **EF Core Performansı**: Salt okunur (read-only) sorgularda her zaman `.AsNoTracking()` kullan; döngü içinde sorgu (N+1) yapmaktan kaçın.
- **Dependency Injection**: Captive dependency oluşturma (Singleton içine Scoped servis enjekte etme).
- **Hata Yönetimi**: İş kuralı hatalarında generic exception fırlatmak yerine Result pattern veya domain-specific exception kullan.
