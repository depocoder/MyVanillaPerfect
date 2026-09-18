# Изменения пака MyVanillaPerfect

Первый заголовок `## x.y.z` этого файла = версия пака (`publish.ps1` сам пишет её в `pack.toml`).
Правило: **каждый publish, который меняет моды/конфиги/ресурспаки, начинается с новой записи здесь** — иначе `publish.ps1`
остановится и попросит её добавить. Новую версию — новым заголовком сверху. Пиши для друзей, человеческим языком.

## 1.2.1 — 2026-09-18

- **Classic Farlands убран** (сервер и пак): Far Lands начинаются на 12,5 млн блоков — никто не долетит, а мод мешал ускорителю генерации
  на сервере. Мир не меняется.
- На сервере — **C2ME**: новые чанки генерируются в ~1,8 раза быстрее (полёты на элитре в неизведанное, LOD-даль). Ставить ничего не надо.
- Towns and Towers: выключена болотная «лодочная» деревня (ставилась с обрезанными краями); болотная деревня Dungeons and Taverns остаётся.
  Файл config/towns_and_towers/structure_enable_or_disable_new.json5 обновится сам.
## 1.2.0 — 2026-09-18

Обновление обычное: просто перезапусти игру. Сервер обновлён тогда же, поэтому 1.1.0 на него больше не пустит («missing mods») — обновись.

### Новое в мире (только в новых чанках; старые постройки не меняются)

- **Towns and Towers** — деревни и аванпосты разбойников в стиле каждого биома (швейцарские в лугах, викинги в снежной тайге,
  корабли в океане…). Аванпосты D&T теперь только в равнинах, в остальных биомах — аванпосты T&T.
- **Dungeons and Taverns: Mineshaft Overhaul** — новые шахты в стиле D&T.
- **Structory: Towers** — башни, маяки, форпосты (без основного Structory).
- Датапаки на сервере: **Challenge Advancements** (новые достижения-челленджи) и **VanillaTweaks: Nether Portal Coords**
  (при входе в портал в чат приходят координаты для связки порталов). Ставить ничего не надо.
- На сервере — **Leaves Be Gone**: листва после сруба дерева исчезает за секунды (серверный мод, у тебя ничего не появится).

### Новое на клиенте

- **Chat Heads** — голова игрока рядом с сообщением в чате.
- **Falling Leaves** — падающие листья у деревьев (снежинки зимой). Настройки — Mod Menu.
- **Cosy Critters & Creepy Crawlies** — птицы, мотыльки и паучки (чисто визуальные частицы, урона нет). Mod Menu → Cosy Critters.
- **Subtle Effects** — мелкие эффекты: искры у костра, Zzz у спящих, пыль, брызги. Водопады у больших ферм ограничены заранее
  (крупные водопады выключены), чтобы не просаживать FPS — включить можно в Mod Menu → Subtle Effects → Environment.
- **spark** — профилировщик: /sparkc profiler start --timeout 60, если лагает клиент; на сервере — spark tps из консоли.
  Как пользоваться — README, раздел «spark».
- **Krypton** — оптимизация сети (и на сервере). Побочка: график Bandwidth в F3+3 показывает 0 — это известно, не баг сети.

Конфиги новых визуальных модов (Chat Heads, Falling Leaves, Cosy Critters, Subtle Effects) приезжают один раз, дальше твои.
## 1.1.0 — 2026-09-17

Minecraft 26.1.2, Fabric 0.19.3. Обновление обычное: просто запусти игру, установщик всё сделает сам.
Перед первым запуском прочитай два пункта «сделай один раз» ниже — там про Java и войс-чат.

### Убрано из пака

- **Simple Voice Chat** — голос теперь только в Discord. Мод слишком шумел, конфликтовал с Flashback и требовал
  лишний порт на сервере. С сервера он тоже снят, так что старый jar у тебя всё равно не заработает — установщик его удалит.
- **Do a Barrel Roll** — крен на элитрах никто не использовал.
- **Speed Happy Ghast** — в Dungeons and Taverns есть своё зачарование на скорость гаста.
- **World Play Time → World Play Time Reborn** — тот же счётчик времени в мире, но под 26.1.2 и с обновлениями.
- Мелочь, которая мешала: FastBack (серверный бэкап, в одиночке не работал), ShatterLib (библиотека без потребителей),
  Voxy World Gen (в мультиплеере LOD-карту генерирует сервер), выключенные шейдеры `*.zip.disabled`, временные файлы
  и конфиги давно удалённых модов.

### Добавлено

- **Ресурспаки теперь приезжают с паком** (раньше каждый ставил сам). Общий набор: Fast Better Grass, Hyper Punchy,
  Enchanted Books: Re-covered, Enchantment Outlines, Mace but 3D, Dungeons Crit Sound, Vocal Villagers, Visual: Armor Trims,
  Fancy Beds, qrafty's Capitalized Font, Icons, Default Dark Mode, Chat Reporting Helper, Translations for Sodium
  и новые: **Animated Items**, **Fresh Food**, **Gentler Weather Sounds** (мягче дождь/гроза), **Motschen's Better Leaves**
  (объёмная листва), **Enhanced Boss Bars**, **BACAP Language Pack** (русские названия достижений BlazeandCave).
  Порядок паков задан профилем **MyVanillaPerfect** в меню ресурспаков (Packed Packs) — выбери его один раз,
  игра запомнит. Свои паки (например VanillaTweaks) можешь оставить — они никуда не денутся, профиль их подхватит.

### Сделай один раз

1. **Java-флаг против вылетов** (если ещё не вписан): Prism → ПКМ по инстансу → Edit → Settings → Java → галка **Java arguments** →
   `-XX:CompileCommand=exclude,io/netty/util/internal/ReferenceCountUpdater.retryRelease0`.
   Без него Java иногда закрывает игру без crash-report через пару часов (`hs_err_pid*.log` в папке инстанса).
   Флаг нужен на любой Java 25 — обновление Java (например, Microsoft OpenJDK 25.0.4) само по себе баг не закрывает.
   Подробности — README, шаг «Java».
2. **Команда установщика**: там же, Custom commands → в Pre-launch command должно быть `-s client` (не `-s both`).
   С `both` тебе качаются и серверные файлы. После замены установщик один раз перекачает моды («Side changed») — это нормально.
3. **Профиль ресурспаков**: Options → Resource Packs → слева профиль **MyVanillaPerfect** → выбрать. Или удали файл
   `config/packed_packs/__version.json` — тогда профиль применится сам при следующем запуске.

### Личные настройки больше не перетираются

Раньше при каждом запуске пак перезаписывал все конфиги. Теперь:
- **Графика и звук** — `options.txt`, Sodium, Iris, настройки шейдеров (`.txt`) — пак не трогает вообще. Sodium Extra и Voxy
  (`sodium-extra-options.json`, `voxy-config.json`) приезжают один раз с моими значениями (см. ниже), дальше твои.
- **Твои предпочтения** — зум (Zoomify), BetterF3, Camera Overhaul, Dynamic FPS, Dynamic Lights, More Culling, Entity Culling,
  ImmediatelyFast, Immersive Hotbar, Overlay Tweaks, AppleSkin (HUD еды), Mod Menu, Dynamic Crosshair, Chest Tracker, Sounds, Sound Muffler, Fancy Toasts,
  Tweakeroo/MaLiLib, Stendhal, CraftPresence, Mouse Tweaks, Ping Wheel (клиент), Inventory Sorting, Shulker Box Tooltip,
  настройки ресурспаков (`.rpo`) и подобное — приезжают **один раз при первой установке**, дальше твои изменения не откатываются.
- **Общие правила сборки** по-прежнему обновляются у всех: серверные конфиги, чанк-лоадеры, Illager Invasion, Voxy Server Side,
  Horseman, DeathFinder, Easy Shulker Boxes, Diagonal Fences, Visual Workbench, Freecam, No Chat Reports, Crash Assistant.

При **этом** обновлении установщик один раз удалит файлы, которые больше не раздаются, и моды создадут их заново с дефолтами:
`voicechat/*`, `controlify/*` (профили геймпада), `flashback/*` (список недавних реплеев — сами реплеи целы),
`packed_packs/*` (профили ресурспаков — новый профиль MyVanillaPerfect приедет с паком), счётчик PatPat.
А `sodium-extra-options.json` и `voxy-config.json` один раз **заменятся на мои** (i9 + 4080: Voxy service threads 10, Render Distance под мою
видеокарту) — после первого запуска поправь под себя: Video Settings → Voxy → Render Distance ~150–250; дальше пак их не трогает.
Если что-то из этого дорого — скопируй папку `config/` до запуска и верни нужные файлы после.

### Сервер

Сервер сам перезапускается после падения и ночью в 05:00 (полный бэкап мира, лежит 15–25 минут; за 5 минут — предупреждение в чат). Днём недоступен дольше 5 минут (ночью — дольше 30) — пиши владельцу.
Включён whitelist — если не пускает, тоже пиши владельцу. Список игроков в меню серверов скрыт специально; онлайн — по Tab в игре.

### Шейдеры

Complementary Reimagined/Unbound r5.9.1 и Solas 3.7b теперь скачиваются с Modrinth (раньше лежали и в паке, и по ссылке —
файл тот же, но при этом обновлении он один раз перекачается). Complementary r5.8.1 тоже остаётся в паке. Настройки шейдеров (`.txt`) — только твои.

## 1.0.0

Первая версия: Fabulously Optimized + vanilla+/QoL моды, раздача через packwiz.

