---
name: handoff
description: Context dolmaya başladığında mevcut durumu .agents/HANDOFF.md dosyasına kaydeder.
---
# Oturum Devir (Handoff) Protokolü
1. Bu oturumda öğrenilen kalıcı bir mimari kural veya önemli bir bug çözümü varsa `save_instinct` MCP aracıyla hafızaya kaydet.
2. Mevcut oturumdaki ilerlemeyi `.agents/HANDOFF.md` dosyasına maksimum 25 satırda şu başlıklarla yaz:
   - **Tamamlanan İşler & Değişen Dosyalar**
   - **Alınan Mimari Kararlar**
   - **Açık Kalan Noktalar & Sıradaki İlk Adım (Next Step)**
3. Kullanıcıya oturumu temizleyip (`/clear`) yeni oturumda `@.agents/HANDOFF.md` dosyasını referans göstererek sıfır token şişmesiyle devam edebileceğini bildir.
