---
name: kb
description: Proje hafızası (ecc-lite-brain) üzerinde 2 aşamalı progresif arama (indeks -> detay) ve NotebookLM bulut kütüphanesini sıfır gereksiz token tüketimiyle sorgular.
---

# Proje Hafızası & Çift Katmanlı Bilgi Protokolü (Dual-MCP)

## 1. Katman 1: Yerel & Global Bilgi Bankası (`ecc-lite-brain`)

Context penceresini doldurmamak için **2 aşamalı progresif arama** standardı uygulanır:

1. **Aşama 1 — Hızlı ve Kompakt İndeks Araması (`search_knowledge_index`):**
   - İlgili anahtar kelimeleri arat (örn: `Avatar`, `EF-Core`, `Auth`).
   - Bu araç her eşleşme için yalnızca ~40-60 token tüketen tek satırlık kompakt başlık ve ID döner:
     `[ID: instincts.md#9 | Global] **[Avatar-Layer-Hierarchy]** (2026-11-02): Avatar katmanlama sırası...`
   - Doğrudan devasa metinler ana context'e yüklenmez.

2. **Aşama 2 — Cerrahi Detay Getirme (`get_knowledge_detail`):**
   - İndekste işine yarayan blokların ID'lerini seç (örn: `"instincts.md#8, instincts.md#9"`).
   - Yalnızca bu spesifik blokların tam metnini context'e çağır.

*(Not: Gerekli görülen durumlarda geriye dönük uyumlu `search_project_knowledge` ile doğrudan tam metin araması da yapılabilir.)*

3. **Öğrenilen Kararları Kaydetme (`save_instinct`):**
   - Bir bug çözüldüğünde, yeni bir mimari karar alındığında veya kritik bir katman hiyerarşisi belirlendiğinde hemen `save_instinct(topic, rule)` aracını çağır.
   - Bilgi kalıcı olarak hafızaya işlenir ve sonraki tüm oturumlarda korunur.

---

## 2. Katman 2: Büyük Dokümanlar & Beceri Kütüphanesi (`notebooklm`)

Büyük mimari referanslar, harici API dokümantasyonları ve global kılavuzlar için NotebookLM MCP'si kullanılır:
- **Skills Kütüphanesi**: `https://gemini.google.com/notebook/063f74b6-7230-4a4f-8232-7663ff1ee9dd`
- **ECC-Lite Mimari Defteri**: `https://gemini.google.com/notebook/f144c149-848c-403f-85dd-24377028a4d7`
- Gerek duyulduğunda `ask_question` aracıyla doğrudan nokta atışı sorular yöneltilerek sadece ilgili özet çekilir.
