# Proje: SQL Data Warehouse Project (Data With Baraa) — PostgreSQL Uyarlaması

## Proje Hakkında
Bu repo, [Data With Baraa](https://github.com/DataWithBaraa/sql-data-warehouse-project) YouTube kanalının
"SQL Data Warehouse Project" portföy projesinin PostgreSQL uyarlamasıdır. Orijinal proje SQL Server +
SSMS kullanıyor; ben bunu **PostgreSQL + DBeaver** ile yapıyorum. Mimari (Medallion: Bronze/Silver/Gold),
repo yapısı, kavramlar ve adımlar aynı kalıyor — sadece SQL Server'a özgü sözdizimi/araçlar PostgreSQL
karşılıklarına çevriliyor.

## Ortam
- **İşletim sistemi**: Windows 11
- **Veritabanı**: PostgreSQL 18 — **doğrudan bilgisayarımda kurulu çalışıyor, Docker kullanmıyorum**
- **GUI/Client**: DBeaver
- **Görev takibi**: Notion (Epics + Tasks database yapısı)
- **Diyagramlar**: Draw.io (orijinal projedeki .drawio dosyaları)

## Repo Yapısı (orijinal projeyle aynı mantık)
```
datasets/       # ERP ve CRM kaynak CSV dosyaları
docs/           # Mimari diyagramlar, data catalog, naming conventions, requirements
scripts/
  bronze/       # Ham veriyi yükleme scriptleri
  silver/       # Temizleme / dönüştürme scriptleri
  gold/         # Analitik modeller (star schema)
tests/          # Veri kalitesi / test scriptleri
```

## Çalışma Tarzım — ÖNEMLİ
Bu proje benim için **öğrenme amaçlı**. İki farklı yardım modu var, ikisini birbirine karıştırma:

1. **Kod yazma / hata ayıklama / SQL çözme görevlerinde**: Bana doğrudan çözümü verme.
   İpucu ver, adım adım düşünmemi sağla, hatamı kendim bulup düzeltmeme izin ver.
2. **Kavramsal "neden böyle / bu nasıl çalışır" sorularında**: Bunlar gerçek öğrenme soruları,
   ipucu modunda cevaplama — tam ve açık açıklama yap. Örnek: "neden CTE yerine subquery
   kullanmadık", "bu index neden bu şekilde çalışıyor", "medallion mimarisi neden 3 katmanlı" gibi
   sorularda doğrudan ve eksiksiz açıkla.

Kısacası: **"Yap bunu" isteklerinde ipucu ver, "Bunu neden/nasıl" sorularında öğret.**

## SQL Server → PostgreSQL Çeviri Notları
Proje ilerledikçe karşılaştığım önemli farkları buraya ekleyeceğiz.

| SQL Server | PostgreSQL | Not |
|---|---|---|
| `NVARCHAR(n)` | `VARCHAR(n)` | `docs/data_catalog.md` içinde uygulandı (Baraa'nın dosyasından uyarlanırken). |
| `IDENTITY` | `GENERATED ALWAYS AS IDENTITY` | Henüz uygulanmadı — Bronze layer script'lerinde ele alınacak. |
| `GETDATE()` | `clock_timestamp()` (`NOW()` değil!) | `proc_load_bronze.sql`'de süre ölçümü (start/end_time) için uygulandı. `NOW()` transaction başlangıç anını döndürür ve aynı transaction içinde hep aynı değeri verir — süre farkı hep 0 çıkar. `clock_timestamp()` her çağrıda gerçek anlık saati verir, süre ölçümü için doğru olan bu. |
| T-SQL `MERGE` | `INSERT ... ON CONFLICT` | Henüz uygulanmadı — upsert mantığı gerektiğinde ele alınacak. |

## Mevcut Durum
- [ ] Requirements Analysis
- [ ] Design Data Architecture
- [ ] Project Initialization
- [ ] Bronze Layer
- [ ] Silver Layer
- [ ] Gold Layer

(Bu listeyi ilerledikçe güncelleyeceğiz — Notion'daki Epic/Task yapısıyla senkron tutulacak.)
