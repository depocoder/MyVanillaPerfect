# MyVanillaPerfect

Кастомная сборка на базе **Fabulously Optimized** — Minecraft **26.1.2** (Fabric, 116 модов).
Раздаётся через [packwiz](https://packwiz.infra.link/) — **обновляется у всех автоматически**.

---

## 🎮 Установка для друзей (Prism Launcher) — с авто-обновлением

1. В Prism создай новый инстанс: **Minecraft 26.1.2**, загрузчик **Fabric**.
2. Скачай **packwiz-installer-bootstrap.jar**:
   <https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar>
   и положи его в папку инстанса (открыть: ПКМ по инстансу → **Folder**; файл кинуть в `minecraft/` или `.minecraft/`).
3. ПКМ по инстансу → **Edit** → вкладка **Settings** → **Custom commands** → поставь галку **Custom commands** и в поле **Pre-launch command** вставь:

   ```
   "$INST_JAVA" -jar "$INST_MC_DIR/packwiz-installer-bootstrap.jar" -s both "https://raw.githubusercontent.com/depocoder/MyVanillaPerfect/main/pack.toml"
   ```

4. Нажми **Play**. При **каждом** запуске моды и конфиги сами обновятся до последней версии. Готово ✅

> Альтернатива без авто-обновления: можно один раз импортнуть `.mrpack` (если он приложен в Releases), но тогда обновлять придётся вручную.

---

## 🔒 Что у тебя НЕ перезапишется

- **`options.txt`** — твои клавиши, графика, чувствительность, громкость, язык.
- **`saves/`** — твои миры.
- Список серверов, скриншоты, логи.

Пак трогает только моды и общие конфиги. При **первом** запуске тебе один раз применятся рекомендованные настройки (если своих ещё нет) — дальше твои не трогаются.

## 🎨 Ресурспаки и шейдеры

Файлы скачаются автоматически, но **включить** их нужно один раз вручную в игре:
**Options → Resource Packs** и **Options → Video Settings → Shader Packs**.
Шейдеры и графику каждый настраивает под своё железо (они намеренно не навязываются).

---

## 🛠️ Для автора (обновление пака)

Поменял моды/конфиги в своём инстансе Prism → запусти **`publish.ps1`** (ПКМ → Run with PowerShell). Он пересоберёт пак и запушит в GitHub — друзьям прилетит при следующем запуске.
