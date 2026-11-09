# Project Instincts & Architectural Decisions (Example Template)

- **[Clean-Architecture-Boundaries]** (Initial): Katmanlar arası bağımlılıklar daima içe doğru (Domain <- Application <- Infrastructure / UI) akmalıdır. Domain ve Application katmanları harici kütüphane ve somut altyapı sınıflarına bağımlı olmamalıdır.
- **[EF-Core-Read-Performance]** (Initial): Salt okunur veritabanı sorgularında `.AsNoTracking()` ve tüm asenkron metotlarda `CancellationToken` zorunludur. N+1 sorgularından kaçınmak için projeksiyon (`Select`) veya hedefe yönelik `Include` kullanılmalıdır.
- **[Strict-Frontend-Typing]** (Initial): Frontend kod tabanında (TypeScript) `any` tipi kesinlikle yasaktır; tüm API yanıtları, bileşen propları ve durum nesneleri açık arayüzler (interface/type) ile tiplenmelidir.
- **[Flutter-Const-And-Isolation]** (Initial): Flutter UI ağacında yeniden çizimleri (re-render) en aza indirmek için uygun her yerde `const` constructor kullanılmalı, durum yönetimi iş mantığından izole edilmelidir.
- **[Ponytail-Minimalism]** (Initial): Mevcut platform kütüphaneleri ve mevcut kod örüntüleri önceliklendirilir; birkaç satırlık iş için asla gereksiz harici paket veya tek kullanımlık soyutlama (Interface/Factory) eklenmez.
