# cx-sidekick

OpenAI Codex CLI'ı Claude Code içinden arka planda çalışan bir yardımcı ajan olarak kullanın. Claude lider ajan olarak kalır: planlar, işi böler, derler ve doğrular. Codex ise arka planda, istediğiniz kadar adlandırılmış oturumda kod yazar ve değişiklikleri denetler.

[English](README.md)

## Neden

- **Limitler ayrıdır.** İki aracın kullanım limitleri ayrıdır; biri azalınca diğeriyle devam edilir.
- **Farklı model, farklı göz demektir.** Başka bir modelin yaptığı denetim, modelin kendi işini denetlerken kaçırdığı hataları yakalar.
- **Paralel çalışma.** Codex arka planda kod yazarken Claude derler, test eder ve sonucu kontrol eder.

Eklentinin Claude'a öğrettiği kural: işi yapan ile doğrulayan ayrı olsun. Claude, Codex'in çıktısını kendisi derleyip test eder ve denetim bulgularını uygulamadan önce çürütmeye çalışır.

## Gerekenler

- Kurulu ve oturum açılmış [Codex CLI](https://github.com/openai/codex): `npm install -g @openai/codex`, ardından bir kez `codex` çalıştırın.
- macOS, Linux veya WSL: bash ve git.
- Yerel Windows: Git for Windows ve PowerShell 7 ya da Windows ile gelen PowerShell 5.1.

Kurulumdan sonra `/cx-sidekick:setup` bunların hepsini kontrol eder.

## Kurulum

cx-sidekick doğrudan bu GitHub deposundan kurulur. Anthropic'in eklenti dizininde yer almaz: dizin, betik içeren eklentileri yalnızca doğrulanmış kuruluşlardan kabul eder ve cx-sidekick sarmalayıcısını betik olarak sunar.

**1. Codex CLI'ı kurun** (`codex --version` zaten çalışıyorsa geçin):

```
npm install -g @openai/codex
codex
```

İlk `codex` çalıştırması oturum açtırır.

**2. Eklentiyi ekleyin.** Claude Code içinde:

```
/plugin marketplace add meteciftci/cx-sidekick
/plugin install cx-sidekick@cx-sidekick
```

Ya da terminalden:

```
claude plugin marketplace add meteciftci/cx-sidekick
claude plugin install cx-sidekick@cx-sidekick
```

**3. Kurulumu kontrol edin.** Projenizde yeni bir Claude Code oturumu başlatın (ya da `/reload-plugins` çalıştırın) ve şunu yazın:

```
/cx-sidekick:setup
```

Codex kurulumunu doğrular ve Claude'un her seferinde istenmeden Codex kullanması için projenin `CLAUDE.md` dosyasına bir bölüm eklemeyi teklif eder.

### Güncelleme ve kaldırma

```
claude plugin marketplace update cx-sidekick
claude plugin update cx-sidekick@cx-sidekick
claude plugin uninstall cx-sidekick@cx-sidekick
```

## Komutlar

Bunları yazabilir ya da doğrudan isteyebilirsiniz ("testleri sen yazarken ayrıştırıcıyı Codex'e yazdır", "bu değişiklik için ikinci bir görüş al"); Claude uygun olanı seçer.

| Komut | Ne yapar |
| - | - |
| `/cx-sidekick:run [ad] [write\|read] <görev>` | Arka planda yeni bir Codex oturumu başlatır |
| `/cx-sidekick:resume <ad> <takip>` | Aynı oturuma devam eder; Codex bağlamı korur |
| `/cx-sidekick:audit [ad] <odak>` | Serbest odaklı salt okunur denetim, yapılandırılmış bulgular |
| `/cx-sidekick:challenge [ad] [--uncommitted \| --commit SHA \| --base DAL] [odak]` | Bir değişikliğin yanlış olduğunu göstermeye çalışan çürütme denetimi |
| `/cx-sidekick:review [ad] [hedef]` | Codex'in hazır `codex review` komutu |
| `/cx-sidekick:status [ad]` | Çalışan ve biten işleri gösterir |
| `/cx-sidekick:setup` | Codex kurulumunu kontrol eder; `CLAUDE.md` bölümü önerir |

### Komut kullanmak zorunda değilsiniz

Slash komutları yalnızca kısayoldur. Normal sohbette "bu işi Codex'e ver", "backend için Codex'i alt ajan olarak kullan" ya da "bu değişiklik için Codex'ten ikinci görüş al" gibi cümleler yeterlidir; Claude ilgili skill'i kendisi yükler ve betiği çalıştırır. Yalnızca `/cx-sidekick:setup` komut olarak yazılmalıdır.

Varsayılan olarak Claude, siz Codex'ten söz ettiğinizde ona başvurur. Claude'un bir projenin her oturumunda, siz her seferinde istemeden Codex'e kendiliğinden iş dağıtmasını istiyorsanız projenin `CLAUDE.md` dosyasında "Lead agent notes" bölümü bulunmalıdır. `/cx-sidekick:setup` bu bölümü eklemeyi teklif eder.

## Nasıl çalışır

Eklenti, `codex exec`, `codex exec resume` ve `codex review` komutlarını saran küçük bir betik içerir: `scripts/cx.sh` (bash) ve `scripts/cx.ps1` (PowerShell 7 veya 5.1). Her işin bir adı ve proje kökünde kendi klasörü vardır, `.codex-runs/<ad>/`:

| Dosya | İçerik |
| - | - |
| `out<n>.md` | Codex'in son raporu (`audit` ve `challenge` için JSON) |
| `events<n>.jsonl` | Codex'in olay akışı |
| `err<n>.log` | stderr |
| `session` | `resume` için kullanılan Codex oturum kimliği |
| `model<n>` | Kullanılan model ve düşünme düzeyi |
| `done` | İş bitince çıkış koduyla birlikte yazılır |

İşler ayrı süreç olarak başlar, bu yüzden başlatan kabuk kapansa da sürer. Raporlar diskte kalır: çıktının tamamı sohbete basılmaz, Claude yalnız gerektiği kadarını okur. `.codex-runs/` klasörü kendini git dışında tutar.

`audit` ve `challenge`, bulguları sabit bir JSON biçiminde döndürür (`scripts/findings.schema.json`): P1-P3 önem derecesi, başlık, dosya, satır, senaryo ve güven düzeyi.

### Model ve düşünme düzeyi

Varsayılan olarak Codex kendi yapılandırmasındaki modeli kullanır. Tek çağrı için `-m <model> -e low|medium|high|xhigh` (Windows'ta `-Model` / `-Effort`) ile, ya da ortamda `CX_MODEL` / `CX_EFFORT` tanımlayarak değiştirebilirsiniz. Claude'a büyük işler ve çürütme denetimi için en güçlü modeli, kısa takipler için daha küçük bir modeli kullanması söylenir.

## Eklenti ne çalıştırır, ne gönderir

- Eklentinin hook'u, MCP sunucusu ve kendine ait ağ kodu yoktur. Yalnızca Claude sarmalayıcı betiği çağırdığında çalışır.
- Betik, bilgisayarınızda kurulu `codex` komutunu proje klasörünüzde çalıştırır. Codex, görev metnini ve okuduğu kodu kendi Codex hesabınız üzerinden OpenAI'a gönderir; kendiniz çalıştırdığınızda olduğu gibi.
- `write` işleri Codex'in `workspace-write` kum havuzunu kullanır ve projedeki dosyaları değiştirebilir. `audit`, `challenge` ve `read` işleri `read-only` kum havuzunu kullanır.
- Eklentinin yazdığı tek dosyalar projenizdeki `.codex-runs/` altındadır.

## Resmi Codex eklentisiyle karşılaştırma

OpenAI, Claude Code için kendi Codex eklentisini yayımlıyor: [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc). Bakımını OpenAI yapar ve iş yönetimi daha derli topludur. cx-sidekick ise aynı anda birden çok iş dağıtan bir lider ajan için tasarlanmış daha hafif bir seçenektir: her işin bir adı vardır ve ayrı ayrı sürdürülebilir, sonuçlar dosyada kalır, bulgular düzenleyebileceğiniz bir şemaya uyar. `challenge` komutunun fikri o eklentideki çürütme incelemesinden alınmıştır. İkisi yan yana kurulabilir.

## Sınırlamalar

- Codex CLI bayrakları sürümden sürüme değişir. Betik `codex exec --json -o --output-schema` ve `codex exec resume` komutlarına göre yazıldı; `/cx-sidekick:setup` sürümünüzde bunların bulunduğunu kontrol eder.
- Codex, kredisi veya limiti bittiğinde de 0 koduyla çıkabilir. Claude'a hata günlüğüne ve `git status` çıktısına bakması söylenir.
- Henüz iptal komutu yok; bir işi durdurmak için `codex` sürecini sonlandırın.

## Lisans

MIT. cx-sidekick bağımsız bir projedir; OpenAI veya Anthropic ile bağlantılı değildir ve onlar tarafından desteklenmemektedir. Codex, OpenAI'ın bir ürünüdür.
