# Karpathy Cerrahi Kodlama İlkeleri & Ponytail Minimalizm Merdiveni

## Bölüm 1 — Karpathy 4 Cerrahi Kodlama İlkesi

1. **Think Before Coding (Kodlamadan Önce Düşün):**
   - Varsayımlarını açıkça belirt. Gizli ya da sessiz varsayımlarla asla ilerleme.
   - Belirsizlik veya çelişki varsa devam etmeden önce kullanıcıya veya ilgili ajana netleştirici soru sor.
   - Doğrudan kod yazmaya atılmadan önce kök nedeni ve sınırları tam olarak belirle.

2. **Simplicity First (Önce Sadelik):**
   - İhtiyaç duyulmayan hiçbir soyutlama, generic wrapper, factory veya spekülatif config katmanı ekleme (YAGNI).
   - "İleride lazım olur" mantığıyla kod yazma; yalnızca mevcut gereksinimi en yalın ve en doğrudan çözen mimariyi uygula.

3. **Surgical Changes (Cerrahi Değişiklikler):**
   - Yalnızca hedeflenen mantığı değiştir. Komşu koda, stil formatlamasına, boşluklara veya alakasız yorumlara dokunma.
   - Diff'i minimum ve tertemiz tut. Sadece kendi yaptığın değişikliklerin yarattığı yetim import veya değişkenleri temizle.

4. **Goal-Driven Execution (Hedefe Dayalı Yürütme):**
   - Her adımı doğrulanabilir bir hedefe veya test koşuluna bağla.
   - "Oldu galiba" demek yasaktır; doğrulama kapısından (derleme/test/analiz) geçmeden görevi tamamlandı sayma.

---

## Bölüm 2 — Ponytail Minimalizm Merdiveni & Borç Standardı

Kod yazmadan önce aşağıdaki 6 basamakta **ilk çalışan durakta dur**:
1. **Var olması şart mı?** (Gereksiz özellik veya kurguyu baştan reddet veya sil).
2. **Kod tabanında zaten var mı?** (Mevcut helper, extension veya utility'yi tekrar üretme, yeniden kullan).
3. **Standart kütüphane/platform özelliği çözüyor mu?** (Platformun yerel dil ve kütüphane imkanlarını kullan).
4. **Kurulu bağımlılıkta var mı?** (Projeye dahil edilmiş mevcut paketleri kullan; birkaç satır kod için yeni NPM/NuGet/Pub paketi ekleme).
5. **Okunabilir tek satır olur mu?** (Gereksiz fonksiyon veya sınıf sarmalayıcısı üretmeden, temiz ve okunabilir ifadeyle çöz).
6. **Minimum çalışan kod + dal/döngü/güvenlik mantığına 1 küçük test.**

### Borç Standardı ve Bilinçli Kestirmeler:
- Bilinçli ve geçici kestirmeleri her zaman şu formatta işaretle:
  `// shortcut: <sınır>, <ne zaman yükseltilmeli>`
- Yanıt sonunda 1-2 satırla bilerek atlanan noktaları ve olası riskleri belirt.
- **Asla Taviz Verilmeyecekler (Non-Negotiable):**
  - Güvenlik ve secret yönetimi,
  - Veri kaybını önleme ve transaction bütünlüğü,
  - Trust-boundary validasyonu (kullanıcı girdisi / dış API girdisi doğrulama),
  - Erişilebilirlik (a11y) standartları.
