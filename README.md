# MyVanillaPerfect — FO 26.3

Независимая сборка для Minecraft 26.3 на Fabric Loader 0.19.5.

## Установка для друга в Prism Launcher

Ветка опубликована на GitHub. Если её когда-нибудь придётся создавать заново, первая отправка выполняется командой:

```powershell
rtk git push -u origin fo-26.3
```

После публикации ссылка ниже доступна другим компьютерам.

Другу нужно выполнить следующие шаги:

1. В Prism Launcher создать **новый пустой** инстанс с Minecraft **26.3** и загрузчиком **Fabric 0.19.5**. Не импортировать Fabulously Optimized и не копировать старые папки `mods` или `config`: посторонние файлы packwiz автоматически не удалит.
2. Скачать [packwiz-installer-bootstrap.jar](https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar).
3. Открыть папку нового инстанса через **ПКМ по инстансу → Folder** и положить JAR в папку `minecraft`.
4. Открыть **Edit → Settings → Custom commands**, включить **Custom commands** и вставить в **Pre-launch command**:

   ```text
   "$INST_JAVA" -jar "$INST_MC_DIR/packwiz-installer-bootstrap.jar" -s client "https://raw.githubusercontent.com/depocoder/MyVanillaPerfect/fo-26.3/pack.toml"
   ```

   Использовать именно `-s client`, чтобы установщик не загружал серверные файлы.
5. В **Edit → Settings → Java** установить максимальную память 6–8 ГБ, включить отдельные **Java arguments** и для Java 25 добавить:

   ```text
   -XX:+UseZGC -XX:CompileCommand=exclude,io/netty/util/internal/ReferenceCountUpdater.retryRelease0
   ```

   `-XX:+UseZGC` выполняет рекомендацию Distant Horizons и устраняет предупреждение о G1GC. Если в поле уже есть `-XX:+UseG1GC`, его нужно удалить: одновременно выбирать два сборщика мусора нельзя. Packwiz не может изменить настройки Java в Prism Launcher, поэтому этот шаг выполняется на каждом компьютере вручную.

6. Нажать **Play**. При первом запуске packwiz скачает моды и конфиги; при следующих запусках будет автоматически проверять обновления ветки `fo-26.3`.
Если GitHub временно недоступен, Prism остановит запуск на pre-launch-команде. Для временного запуска уже установленной версии можно выключить **Custom commands**, а после восстановления сети включить обратно.

### Если у друга уже была другая сборка

Надёжнее создать отдельный пустой инстанс по инструкции выше. Если используется существующий инстанс, игру нужно закрыть и полностью очистить его папки `mods` и `config`, иначе старые моды и настройки могут остаться рядом с файлами FO 26.3 и вызвать конфликт. Миры, `options.txt`, `servers.dat` и скриншоты перед очисткой можно сохранить отдельно.

## Независимая ветка

`fo-26.3` создана как orphan-ветка: у неё нет общего родительского коммита с `main`, и она не наследует моды, конфиги, ресурспаки или шейдеры основной сборки.

Предыдущая неправильная версия сохранена локально в восстановимой архивной ветке:

`archive/fo-26.3-2026-10-07`

Начальная чистая сборка создана 7 октября 2026 года. В неё вошли 48 модов и 65 распространяемых конфигурационных файлов. Ресурспаки и шейдеры других веток не переносились.

## Источник сборки

`publish.ps1` для этой ветки автоматически читает файлы только из отдельного инстанса:

```text
C:\Users\depo_pc\AppData\Roaming\PrismLauncher\instances\Fabulously Optimized 26.3(1)\minecraft
```

Перед публикацией скрипт сверяет версию Minecraft в `pack.toml` и `mmc-pack.json`. Если выбран инстанс другой версии, публикация останавливается до изменения файлов пака.

## Как выбрать сборку для публикации

Выбор выполняется переключением Git-ветки.

FO 26.3:

```powershell
rtk git switch fo-26.3
rtk powershell -ExecutionPolicy Bypass -File .\publish.ps1
```

Основная сборка:

```powershell
rtk git switch main
rtk powershell -ExecutionPolicy Bypass -File .\publish.ps1
```

На `main` используется старый основной инстанс `Fabulously Optimized(4)`. На `fo-26.3` автоматически используется `Fabulously Optimized 26.3(1)`.

## Проверка без отправки

Чтобы пересобрать и создать локальный коммит, но не отправлять ветку на GitHub:

```powershell
rtk powershell -ExecutionPolicy Bypass -File .\publish.ps1 -NoPush
```

Для первой публикации новой версии, когда номер в changelog намеренно ещё совпадает с `pack.toml`, можно дополнительно передать `-AllowSameVersion`.

## Ресурспаки

Сборка не распространяет ресурспаки и не создаёт профиль Packed Packs. `resourcepacks.list` намеренно пуст, а `publish.ps1` удаляет случайно попавшие в сборку Fresh Animations и FA+.

Каждый пользователь скачивает нужные ресурспаки вручную с их официальных страниц и кладёт ZIP-файлы в папку `minecraft/resourcepacks`. Делать это следует после первого обновлённого запуска версии 26.3.4, потому что packwiz сначала удалит ранее опубликованные этой веткой ZIP-файлы.

## Отправка на GitHub

Ветка опубликована как `origin/fo-26.3`. Обычный запуск `publish.ps1` создаёт коммит и выполняет push текущей ветки; при первом push новой ветки скрипт автоматически создаёт upstream. Перед отправкой проверь `git status` и `git log`.
