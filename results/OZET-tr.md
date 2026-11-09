# V8 sonuçları: aynı $6 sunucuda altı dil (9 Kas 2026, gün 2; Express gün 1'de de ölçüldü)

Kutu: DigitalOcean s-1vcpu-1gb ams3 <public-ip> (iki gün aynı kutu). Gün 1: cpu 945 olay/s, fsync 5.914/s. Gün 2: cpu 819, fsync 5.688.
Kural: her dil framework'ünün belgesindeki gibi çalıştı, ayar yok (`olcum/yarisma/*/README.md`). 5 dk rampa (`--ramp-seconds 300`), knee'nin %90'ında 5 dk tutuş, %10 adımla aşağı. İki k6 üreticisi (tavan 50.000).
Altısı da test_api 28/28 ve gizli testi (önbellek yok, token anında, kill -9 sırasında kabul edilen her yazı diskte) geçti.

| Sıra | Yarışmacı | Skor | Kırılma (rampa) | Nasıl | Tutuşta p95 | istek/s | Tutuşta bellek | Boşta bellek |
|---|---|---|---|---|---|---|---|---|
| 1 | Rust / Axum + sqlx | **17.600** | 21.666 | OOM (bağlantıları hiç kapatmıyor: 17.600 kullanıcı = 17.605 açık bağlantı, ~23 KB/bağlantı; 50k rampasında ~29.000 bağlantıda bellek bitti) | 566 ms | 1.562 | 579 MB | 6 MB |
| 2 | Node / Express | **15.800** (gün 1 de 15.800) | 17.500 (gün 1 de) | hata + `SYN flooding` (keep-alive 5 sn) | 476 ms | 1.388 | 471 MB | 83 MB |
| 3 | Go / net/http + database/sql + mattn | **12.200** | 15.000 | OOM: havuzun sınırı yok, yazma kuyruğunda ~1.000 SQLite bağlantısı (notes.db tanıtıcısı 7-9 → 3.176, iş parçacığı 4 → 470), 633 MB'ta öldürüldü (`tani/tani-go-nethttp.log`) | 206 ms | 1.083 | 697 MB | 9 MB |
| 4 | Java / Spring Boot (Tomcat) | **6.800** | 7.500 | hata + `SYN flooding`: Tomcat maxConnections 8.192 (11.000 kullanıcıda açık dosya 8.225'te sabit, bellek 405 MB sabit; `tani/tani-java-spring.log`) | **15 ms** | 607 | 553 MB | 186 MB |
| 5 | PHP-FPM + nginx (Ubuntu varsayılanı) | **5.400** | 6.666 | hata: nginx worker_connections 768 (açık bağlantı ≤ 879), FPM 5 işçi | 283 ms | 481 | 114 MB | 24 MB |
| 6 | Python / FastAPI (`fastapi run`, 1 işçi) | **2.000** | 3.333 | gecikme > 1 sn (3.000/2.700/2.400/2.200 tutuşları p95 ile kaldı), rampada %40 hata | 878 ms | 176 | 137 MB | 77 MB |

Notlar:
- Rust ile Express arası %11, aramanın adım büyüklüğü (%10) kadar: "Rust önde ama tek adım".
- Bellek ölçüsü (cgroup) anon ağırlıklı; soket tamponu değil. Go ve Java IPv6 (çift yığın) dinlediği için `tcp_inuse` sütunu onlarda 4-6 görünür, geçersiz; bağlantı sayısı teşhiste `/proc/<pid>/fd` ile sayıldı.
- Maliyet: gün 1 ~$0,30, gün 2 $0,44.
