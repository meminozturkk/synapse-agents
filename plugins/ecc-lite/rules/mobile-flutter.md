---
trigger: glob
globs: "*.dart, pubspec.yaml"
description: "Flutter ve Dart mobil geliştirme kuralları"
---
# Mobile (Flutter / Dart) Kuralları
- **Klasör Yapısı**: Feature-first klasör mimarisini ve katman ayrımını (presentation, domain, data) koru.
- **Performans**: Widget ağacında gereksiz rebuild önlemek için mümkün olan her yerde `const` constructor kullan; büyük widget'ları alt bileşenlere böl.
- **State Yönetimi**: Immutable state prensibini koru; `BuildContext` nesnesini `async` boşluklarından sonra (`if (!context.mounted) return;`) kontrol etmeden kullanma.
