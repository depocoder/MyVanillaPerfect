# MyVanillaPerfect

Кастомная сборка на базе **Fabulously Optimized** — Minecraft **26.1.2** (Fabric, ~145 модов, vanilla+ / QoL).
Раздаётся через [packwiz](https://packwiz.infra.link/) — **обновляется у всех автоматически при запуске игры**.
Что изменилось в последнем обновлении — в [CHANGELOG.md](CHANGELOG.md).

---

## 🎮 Установка для друзей (Prism Launcher) — с авто-обновлением

1. В Prism создай **новый пустой** инстанс: **Minecraft 26.1.2**, загрузчик **Fabric**.
   **НЕ импортируй Fabulously Optimized** и не копируй чужую папку `mods` — packwiz удаляет только те файлы, которые ставил сам,
   и всё лишнее останется навсегда (старые версии модов рядом с новыми, конфликты, вылет при запуске).
2. Скачай **packwiz-installer-bootstrap.jar**:
   <https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar>
   и положи его в папку инстанса (открыть: ПКМ по инстансу → **Folder**; файл кинуть в `minecraft/` или `.minecraft/`).
3. ПКМ по инстансу → **Edit** → вкладка **Settings** → **Custom commands** → поставь галку **Custom commands** и в поле **Pre-launch command** вставь:

   ```
   "$INST_JAVA" -jar "$INST_MC_DIR/packwiz-installer-bootstrap.jar" -s client "https://raw.githubusercontent.com/depocoder/MyVanillaPerfect/main/pack.toml"
   ```

   Именно `-s client` (не `both`): с `both` установщик тянет и серверные файлы. Если у тебя уже стояло `-s both` — просто поменяй;
   при первом запуске установщик один раз перекачает моды («Side changed»), это нормально.

4. **Java** — там же, **Edit → Settings → Java**:
   - **Java arguments**: поставь галку и вставь в поле

     ```
     -XX:CompileCommand=exclude,io/netty/util/internal/ReferenceCountUpdater.retryRelease0
     ```

     Зачем: у Java 25 (Prism сам скачивает 25.0.1) есть баг JIT-компилятора ([JDK-8374463](https://bugs.openjdk.org/browse/JDK-8374463)) —
     игра **закрывается без crash-report** через 0,5–5 часов, в папке инстанса появляется `hs_err_pid*.log`. Флаг это лечит,
     на производительность не влияет. **Флаг обязателен на любой Java 25**: обновление Java само по себе баг не закрывает
     (исправление в 25u на сентябрь 2026 не подтверждено), Java 21 игра не примет.
     Если хочешь более свежую Java (без известных регрессий; автор играет на ней): Microsoft OpenJDK 25.0.4
     (`winget install --id Microsoft.OpenJDK.25 --exact`) и в Prism → Java → **Java installation** укажи
     `C:\Program Files\Microsoft\jdk-25.0.4.x-hotspot\bin\javaw.exe`; флаг всё равно оставь.
   - **Memory**: **Maximum memory allocation** 6–8 ГБ достаточно, больше 12 ГБ не ставь (Java тратит время на сборку мусора, а не на игру).

5. Нажми **Play**. При **каждом** запуске моды, конфиги и ресурспаки сами обновятся до последней версии. Готово ✅

6. Один раз после первого запуска: **Options → Resource Packs** → слева выбери профиль **MyVanillaPerfect** (это меню Packed Packs).
   Профиль включает общий набор ресурспаков в правильном порядке. Игра его запомнит.

> **Не обновляется / нет интернета / GitHub недоступен?** Установщик завершится с ошибкой и Prism не запустит игру.
> Временный обход: **Edit → Settings → Custom commands** → снять галку **Custom commands** → играть на уже скачанных файлах.
> Когда сеть вернётся — поставить галку обратно. Вручную моды не докачивай.

### ⚠️ Переходишь с Fabulously Optimized или моды дублируются?

Закрой игру, открой папку инстанса (ПКМ → **Folder**) и **удали папки `mods` и `config` целиком**
(старые конфиги FO тоже не нужны: часть из них пак не раздаёт, и они бы остались у тебя навсегда).
Запусти игру — packwiz скачает всё заново и дальше будет сам удалять старые версии.
Если сомневаешься — проще создать новый пустой инстанс по шагам выше и перенести в него `saves/`, `options.txt`, `servers.dat`, `resourcepacks/` (свои паки).

---

## 🔒 Что у тебя НЕ перезапишется

- **`options.txt`** — клавиши, графика, чувствительность, громкость, язык. `saves/`, список серверов, скриншоты, логи.
- **Графика и шейдеры** — пак раздаёт только сами шейдер-паки; настройки Sodium, Sodium Extra, Iris, Voxy и `.txt` шейдеров
  каждый подбирает под своё железо, пак их не трогает.
- **Личное**: профили геймпада (Controlify), реплеи Flashback, плащи, статистика, свои ресурспаки — не раздаются.
- **Настройки-предпочтения** (зум, BetterF3, HUD еды AppleSkin, тряска камеры, Dynamic FPS, динамический свет, культинг, HUD, звуки, хоткеи Tweakeroo,
  CraftPresence, Mouse Tweaks, сортировка инвентаря, настройки ресурспаков `.rpo` и т.п.) —
  приезжают **один раз** при первой установке, дальше твои изменения не откатываются.

Пак принудительно обновляет только моды, ресурспаки из общего набора и «общие правила» сборки: серверные конфиги, чанк-лоадеры,
Illager Invasion, Voxy Server Side, Horseman, DeathFinder, Easy Shulker Boxes, No Chat Reports, Freecam, Crash Assistant, перф-пресеты.

## 🎨 Ресурспаки и шейдеры

**Шейдеры** скачаются автоматически, но **включить** их нужно один раз вручную:
**Options → Video Settings → Shader Packs**. Графику и настройки шейдера каждый подбирает под своё железо.

**Ресурспаки** общего набора приезжают с паком и включаются профилем **MyVanillaPerfect** (шаг 6). Свои паки клади в `resourcepacks/`
как обычно — пак их не удаляет. В профиле они не включены; включай сверху общего набора (или сделай копию профиля и правь её).

### Vanilla Tweaks — у каждого свой

Vanilla Tweaks пак **не раздаёт**: он собирается на [vanillatweaks.net](https://vanillatweaks.net/picker/resource-packs/) под себя.
Если хочешь такой же набор, как у автора — отметь на сайте паки из списка ниже (версия сайта **26.2**, пак работает на 26.1.2),
скачай zip и положи в `resourcepacks/`. Профиль MyVanillaPerfect подхватит любой файл с именем `VanillaTweaks*.zip` и поставит его
на своё место (над Icons и шрифтом, под Fancy Beds). `DarkUI` можно не брать — тёмный интерфейс уже даёт Default Dark Mode.

<details>
<summary>Список паков автора (Selected Packs.txt из VanillaTweaks_r897971_MC26.2.x.zip)</summary>

```
Version: 26.2
Packs:
  SlimesPurple, DarkerDarkOakLeaves, HungerBarsMelon, SpinningBurningSkullPainting, WhatSpyglassMeme, VisualSaplingGrowth,
  RedIronGolemFlowers, ConsistentSmoothStone, ColoredTooltipCyan, ColoredWidgetsPurple, LowerFire, VariatedVillagers,
  VariatedPumpkins, ColoredHeartsPurple, BrighterNether, HDEndFlash, PingColorIndicator, RainbowExperience, OldXpSounds,
  OldDamageSounds, XmasChests, TechnobladePigs, Beeralis, VisualHoney, GroovyLevers, FullAgeCropMarker, DirectionalHoppers,
  BetterObservers, MusicDiscRedstonePreview, DirectionalDispensersDroppers, SidewaysNuggets, PolishedStonesToBricks,
  GoldenCrown, SplashXpBottle, BetterParticles, SofterWool, CherryPicking, AnimatedCampfireItem, GlassDoors, FencierFences,
  CopperToolOxidization, SolidSlime, StemToLog, SmootherWarpedPlanks, PlainWolfArmor, SmileyAxolotls, GreenAxolotl,
  NumberedHotbar, DarkUI, HotbarSlotHighlight, ColoredHotbarSelPurple, RedstonePowerLevels, CleanRedstoneDust

Combined packs:
  CleanRedstoneDust+RedstonePowerLevels, ColoredHotbarSelPurple+HotbarSlotHighlight, DarkUI+NumberedHotbar, GreenAxolotl+SmileyAxolotls
```

</details>

Чтобы собрать такой же набор: на vanillatweaks.net выбрать версию 26.2 и отметить паки из списка выше, нажать Download, zip положить в `resourcepacks/`.
Список выше — запасной вариант на случай, если ссылка перестанет открываться.

## 🖥️ Сервер

- Адрес и порт — у владельца. На сервере **whitelist**: если пишет «You are not white-listed» — напиши владельцу, он добавит ник.
- Сервер сам перезапускается после падения (15 с) и **каждую ночь в 05:00** (полный бэкап мира — сервер лежит примерно **15–25 минут**,
  за 5 минут до этого в чат приходит предупреждение). Днём недоступен **дольше 5 минут** (ночью — дольше 30) —
  напиши владельцу: значит, он остановлен вручную или упал три раза подряд и ждёт человека.
- Список игроков в меню серверов скрыт (`hide-online-players`) — специально; кто онлайн, видно в игре по Tab.
- Голосовой чат в игре убран (1.1.0) — общаемся в Discord.

## 🔥 spark: как пользоваться (если лагает)

spark появляется в паке и на сервере **с версии 1.2.0** (см. CHANGELOG; раньше команды ниже не работают). Команды пишутся в чат игры (на сервере — с правами оператора или из консоли сервера; в одиночке — просто так).

| Хочу понять… | Команда | Что смотреть |
|---|---|---|
| Сервер тормозит? | `/spark tps` | TPS должен быть ~20; MSPT (время тика) < 50 мс. Если MSPT 50+ — серверу тяжело |
| Из-за чего тормозит сервер | `/spark profiler start --timeout 60` (на сервере) | Через 60 с в чат придёт ссылка `spark.lucko.me/…` — открой, вкладка *Flame graph*/дерево: верхние строки с самым большим % и есть виновник (мод, ферма, чанк) |
| У меня лагает клиент (низкий FPS, фризы) | `/sparkc profiler start --timeout 60` (клиентская версия команды) | Так же ссылка; смотри, что грузит *Render thread* |
| Память / сборщик мусора | `/spark gc` и `/spark heapsummary` | Частые долгие паузы GC = мало памяти или утечка; heapsummary — ссылка на разбор, что занимает память |
| Что стоит на сервере | `/spark health` | TPS, память, CPU одной строкой |

Ссылку из чата пришли владельцу — по ней видно всё нужное. Профилировать лучше **в тот момент, когда лагает** (например, рядом с фермой),
`--timeout 60` сам остановит профайлер через минуту. Остановить раньше: `/spark profiler stop`.

## 🧯 Если игра вылетела

Откроется окно **Crash Assistant** — нажми кнопку загрузки логов и **пришли ссылку своему боссу** (владельцу сборки) — окно само подскажет, куда.
Если окно не открылось, а в папке инстанса лежит `hs_err_pid*.log` — это баг Java из шага 4: проверь, что флаг вписан.

---

## 🛠️ Для автора (обновление пака)

1. Поменял моды/конфиги/ресурспаки в своём инстансе Prism → добавь сверху `CHANGELOG.md` заголовок `## x.y.z — дата` и что изменилось для друзей
   (версия из первого заголовка автоматически попадёт в `pack.toml`; без новой записи `publish.ps1` не даст опубликовать изменения содержимого).
2. `publish.ps1 -DryRun` — покажет, что добавится/удалится/изменится в паке, ничего не трогая (репо и GitHub не нужны, нужен Modrinth).
3. **`publish.ps1`** (ПКМ → Run with PowerShell, нужен VPN для GitHub). Он пересоберёт пак и запушит — друзьям прилетит при следующем запуске.
   `-NoPush` — закоммитить и посмотреть глазами, потом `git push`. Для теста на одном друге — публиковать с ветки `staging` (URL `…/staging/pack.toml`), затем `git merge --ff-only`.
   Что раздаётся, а что нет — списки `$excludeConfig` / `$excludeConfigDirs` / `$preserveConfig` в начале скрипта
   (личное и графика — не раздаём; предпочтения — только при первой установке; политика пака — всегда).
4. **Ресурспаки** — только по списку `resourcepacks.list` (порядок строк = порядок в игре, первая строка — верхний пак). Добавить пак:
   строка `mr:<slug>@<version-id>` (Modrinth) → `publish.ps1` сам сделает `packwiz mr add` и перепишет профиль `MyVanillaPerfect`.
   Убрать — удалить строку. VanillaTweaks / Fresh Animations / Patrix и прочее личное в пак не попадут никогда (стоп-лист в скрипте).
5. Готовность к следующей версии Minecraft: `node check-upgrade.js 26.3` (нужен Node.js, читает `mods/*.pw.toml`, спрашивает Modrinth).
   Ворота предварительные (окончательно решаются при миграции): серверные моды 100 %, клиентские ≥ 90 %; общий ориентир — ≥ 90 % всех модов пака.
   Для текущей версии (`node check-upgrade.js 26.1.2`) скрипт просто перечисляет моды без версии под неё.
