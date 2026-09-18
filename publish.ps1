# publish.ps1 v1.1.2 (2026-09-18: prevVersion из HEAD; v1.1.1 2026-09-17, ревизия после проверки RUNBOOK) — обновить пак из инстанса и залить друзьям одной командой.
# Запуск: ПКМ по файлу -> "Run with PowerShell"
#   или в терминале:  powershell -ExecutionPolicy Bypass -File publish.ps1 [-DryRun] [-NoPush] [-AllowSameVersion]
#
#   -DryRun            ничего не трогает: собирает пак во ВРЕМЕННОЙ копии репо и печатает, что изменилось бы
#                      (нужен интернет для Modrinth; GitHub/VPN не нужен). Git не вызывается.
#   -NoPush            всё сделать и закоммитить, но не пушить (посмотреть глазами, потом git push руками).
#   -AllowSameVersion  разрешить publish без новой записи в CHANGELOG.md (по умолчанию — стоп, если изменились
#                      mods/config/resourcepacks/shaderpacks, а версия в CHANGELOG та же, что уже опубликована).
#
# Что делает: пересобирает метаданные модов из твоего инстанса (прямые ссылки на Modrinth; jar без Modrinth-версии,
# например пропатченный мод, кладётся в пак как файл), синхронит config/shaderpacks/emotes, раздаёт ресурспаки
# СТРОГО по списку resourcepacks.list (+ default-профиль Packed Packs с порядком), обновляет packwiz-индекс,
# проставляет preserve, пишет версию из CHANGELOG.md и пушит в GitHub. Друзья получают обновление при следующем запуске.
#
# Правила раздачи конфигов (три класса, см. PATCHES-pack.md):
#   A) $excludeConfig / $excludeConfigDirs — НЕ раздаём вообще: личные данные, кэши, state, временные файлы
#      и ЛИЧНАЯ ГРАФИКА (принцип «графику и шейдеры не синкаем»: sodium/iris/sodium-extra/voxy — каждый под своё железо).
#      Удалённый из индекса файл packwiz-installer СТИРАЕТ у друзей один раз, мод пересоздаст дефолт.
#   B) $preserveConfig — раздаём только при первой установке (preserve = true в index.toml):
#      графические и личные предпочтения (зум, HUD, звуки, культинг, анимации). Друг поменял — больше не откатится.
#      Обратная сторона: твои правки этих файлов до друзей уже не дойдут (только при первой установке).
#   C) всё остальное — «политика пака», перезаписывается у всех при каждом запуске:
#      серверные *-server.toml, chunkloaders, illagerinvasion, vss, horseman, deathfinder, easy shulker boxes (iteminteractions),
#      diagonal, visualworkbench, freecam, NCR, crash_assistant, перф-пресеты (sodium-mixins, lithium…).
#      v1.1.1 (замечание ревью 17.09): appleskin / modmenu / rrls — чисто клиентские UI-предпочтения без влияния на геймплей,
#      перенесены в класс B ($preserveConfig): приезжают один раз, дальше друг настраивает сам.

param([switch]$DryRun, [switch]$NoPush, [switch]$AllowSameVersion)

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

# ===== ПУТИ (поменяй, если перенесёшь инстанс/packwiz) =====
$inst = "C:\Users\depo_pc\AppData\Roaming\PrismLauncher\instances\Fabulously Optimized(4)\minecraft"
$realPack = $PSScriptRoot                   # папка этого скрипта = папка пака
$pack = $realPack
$pw   = "C:\Users\depo_pc\go\bin\packwiz.exe"
$ua   = @{ 'User-Agent' = 'MyVanillaPerfect/publish.ps1 (github.com/depocoder/MyVanillaPerfect)' }
$proxy = 'http://127.0.0.1:20808'  # локальный прокси/VPN для доступа к GitHub (поменяй порт, если у тебя другой)
$sideCache = Join-Path $env:LOCALAPPDATA 'MyVanillaPerfect\side-cache.json'   # кэш client/server-side с Modrinth (вне репо)

# ===== A) НЕ РАЗДАЁМ (имена файлов, wildcard robocopy; матчится на любом уровне config/) =====
$excludeConfig = @(
  # личная графика/шейдеры/мир — было и раньше
  'sodium-options.json','iris.properties','emotecraft.json','shulkerboxtooltip_mp_ender_chest_cache.dat','litematica.json*',
  # Voxy World Gen: мод только у владельца (тест-миры), в пак не идёт -> и конфиг тоже
  'voxyworldgenv2.json',
  # удалённые решением 17.09 моды: если файлы ещё лежат — не раздавать (Do a Barrel Roll, Simple Voice Chat)
  'do_a_barrel_roll-*.json','voicechat-*.properties',
  # личные данные / state / кэши (pc-05, modconfig-06, consistency-02)
  'controlify.json*','capes.json5',
  'my_totem_doll-known-player-uuids.json5','my-totem-doll-known-player-uuids.json5',
  'sodium-fingerprint.json','username-cache.json','player-volumes.properties','category-volumes.properties',
  'patpat-client-stats.json5','.data.json','better_screenshots.json','imgui.ini','.flashback.json.backup',
  # мусор (modconfig-08)
  '*.tmp','*.bak','*.backup'
)
# Папки: голое имя = папка с таким именем на любом уровне; путь с '\' = только этот путь относительно config\
$excludeConfigDirs = @(
  'litematica','punchy',                                  # было и раньше
  'controlify','cape-provider','flashback',               # профили геймпада, провайдер плащей, реплеи/окна Flashback
  'packed_packs',                                         # личные профили/настройки Packed Packs владельца; default-профиль пака пишется отдельно (шаг 2b)
  'voicechat',                                            # Simple Voice Chat удалён из пака (решение 17.09)
  'worldplaytime','worldplaytimereborn',                  # личный HUD времени в мире
  'chunky',                                               # tasks/ = личное состояние прегена (мода в паке нет)
  'spark',                                                # spark: tmp-client/ и config.json — временное/личное (этап 4)
  'modlist_history',                                      # crash_assistant: история эталонных модлистов владельца
  'modpack_defaults','.puzzle_cache','cache',             # снимок дефолтов FO, кэши (моды пересоздают сами; 'cache' = inventory-particles\cache и любые другие)
  'inventory-particles\cache'
)
# ===== B) РАЗДАЁМ ОДИН РАЗ (preserve = true; пути относительно корня пака, wildcard PowerShell -like) =====
# ТОЛЬКО графика и личные предпочтения. Геймплей и серверные политики сюда НЕ добавлять (решение 17.09, п.5).
$preserveConfig = @(
  # графика / производительность (каждый под своё железо); решение владельца 17.09 (вопрос 4): Sodium Extra и Voxy — preserve, а не исключение
  'config/sodium-extra-options.json','config/voxy-config.json',
  # v1.1.2 (этап 4): визуальные клиентские моды — дефолты владельца один раз, дальше каждый крутит сам
  'config/chat_heads.json*','config/fallingleaves*.json','config/cosycritters.json','config/subtle_effects/*','config/fzzy_config/*',
  'config/sound_physics_remastered/*','config/ambientsounds.json','config/particlerain/*','config/creativecore-client.json',
  'config/dynamic_fps.json','config/lambdynlights.toml','config/moreculling.toml','config/entityculling.json',
  'config/immediatelyfast.json','config/skyboxify.json','config/bettergrass.json','config/continuity.json',
  'config/sodium-shadowy-path-blocks-options.json','config/blur.json','config/BBEConfig.json','config/iris-excluded.json',
  'config/entity_model_features.json','config/entity_texture_features.json','config/skinlayers.json','config/animatica.properties',
  'config/euphoria_patcher/settings.toml','config/fullscreenfix.properties','config/ixeris.toml','config/explosiveenhancement.json',
  # звук
  'config/sounds/*','config/extremesoundmuffler.json5',
  # HUD / интерфейс / камера
  'config/betterf3.json','config/zoomify.json','config/cameraoverhaul.toml','config/immersive-hotbar.json5','config/overlaytweaks.json',
  'config/dynamiccrosshair.json5','config/detailarmorbar.json','config/ukus-armor-hud.toml','config/status-effect-bars.json',
  'config/betterstats.json','config/daycount.json5','config/pingwheel.json','config/fancytoasts/*','config/pickupnotifications.toml',
  'config/PaginatedAdvancements.json5','config/inventory_particles.json5','config/my_totem_doll.json5','config/languagereload.json',
  # личные инструменты / хоткеи
  'config/tweakeroo.json','config/malilib.json','config/patpat/patpat-client.json5','config/stendhal/*','config/craftpresence.json',
  'config/chesttracker.json5','config/whereisit.json5','config/inventorysorter.json','config/nemos-inventory-sorting/*',
  'config/shulkerboxtooltip.json5','config/boatiview/client.toml','config/drop_confirm.json5','config/fastquit.toml','config/fwa.json',
  'config/afkcinematics.properties','config/advancementscreenshot.json5','config/fabrishot.properties','config/resourcify.json',
  'config/respackopts/*','config/lighty/*','config/locator_lodestones.json','config/MouseTweaks.cfg','config/cherishedworlds-client.toml',
  'config/clickthrough.toml','config/autoreconnectrf.json',
  # UI-предпочтения без влияния на геймплей (v1.1.1, ревью 17.09): HUD еды AppleSkin, сортировка списка Mod Menu, экран загрузки rrls
  'config/appleskin.json5','config/modmenu.json','config/rrls.toml',
  # настройки ресурспаков (Respackopts) — раздаём один раз
  'resourcepacks/*.rpo'
)
# ===== Моды, которые лежат в инстансе, но в пак НЕ идут (wildcard по имени jar) =====
# voxy-worldgen: на сервере LOD генерирует voxy-server-side; владелец держит мод локально для тест-миров.
# Остальные — удалены из пака решением 17.09 (страховка на случай, если jar снова окажется в инстансе).
$excludeMods = @('Voxy World Gen*','voicechat-fabric-*','do_a_barrel_roll-*','speed-happy-ghast*')
# ===== Side =====
# Автоматически: мод с Modrinth client_side=required и server_side=unsupported -> side='client' (одним batch-запросом, кэш в $sideCache).
# 'server' автоматически НЕ ставится (worldgen-моды вроде Classic Farlands нужны и в одиночке у владельца).
# $sideOverride — ручные исключения поверх автоопределения (ключ = имя pw.toml без расширения). Это ЕДИНСТВЕННЫЙ механизм side:
# ручные правки mods\*.pw.toml стираются при каждом publish (pw.toml пересобираются из инстанса).
$sideOverride = @{
  'fabrishot' = 'client'; 'stendhal' = 'client'; 'world-play-time-reborn' = 'client'
  # v1.1.1: Subtle Effects на Modrinth server_side=optional (не unsupported) -> автоопределение дало бы both; мод чисто клиентский (этап 4, партия 7)
  'subtle-effects' = 'client'
  # v1.1.2 (этап 4): fzzy-config на Modrinth required/required -> both; это библиотека Subtle Effects, серверу не нужна
  'fzzy-config' = 'client'
  # v1.1.3 (1.2.2): Sound Physics (server optional) и CreativeCore (required/required) — на сервере не нужны
  'sound-physics-remastered' = 'client'; 'creativecore' = 'client'
}
# shaderpacks: *.zip.disabled в пак не идут; .pw.toml на «выключенные» у владельца шейдеры оставляем —
# у друзей они продолжают скачиваться с Modrinth (поставь $false, чтобы .pw.toml выключенных тоже не раздавать)
$shipDisabledShaderMeta = $true
# ===== Ресурспаки: только по списку =====
$rpList = Join-Path $realPack 'resourcepacks.list'
# стоп-лист: такие файлы не раздаются НИКОГДА, даже если попали в список или в resourcepacks/ пака
$rpNever = @('VanillaTweaks*','FreshAnimations*','FA+*','Patrix*','Dramatic*','Redstone*','Mandala*','EvenBetterEnchants*','Theone*')
$rpProfileName = 'MyVanillaPerfect'   # default-профиль Packed Packs (config/packed_packs/profiles/resourcepacks/<name>.profile.json)
$rpAliases = [ordered]@{ 'regex:file\/VanillaTweaks.*' = 'regex:file\/VanillaTweaks.*' }   # личный VT друга подхватится под любым именем

# Прокси задаём ТОЛЬКО для этой сессии скрипта; систему не трогаем, после выхода сбросится сам.
# (Само приложение-VPN при этом должно быть запущено — скрипт задаёт лишь адрес.)
$env:HTTP_PROXY  = $proxy
$env:HTTPS_PROXY = $proxy

$utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-MrToml($path,$fn,$nm,$side,$v){
  $file = $v.files | Where-Object { $_.filename -eq $fn } | Select-Object -First 1
  if(-not $file){ $file = $v.files | Where-Object { $_.primary } | Select-Object -First 1 }
  if(-not $file){ $file = $v.files | Select-Object -First 1 }
  $t = "filename = '$fn'`nname = '$nm'`nside = '$side'`n`n[download]`nhash-format = 'sha512'`nhash = '$($file.hashes.sha512)'`nmode = 'url'`nurl = '$($file.url)'`n`n[update.modrinth]`nmod-id = '$($v.project_id)'`nversion = '$($v.id)'`n"
  [System.IO.File]::WriteAllText($path,$t,$utf8)
}
function Test-AnyLike($name,$patterns){ foreach($p in $patterns){ if($name -like $p){ return $true } }; return $false }
function Get-TomlValue($text,$key){ if($text -match "(?m)^$key\s*=\s*([`"'])(.*?)\1\s*$"){ return $Matches[2] }; return $null }
function Set-TomlSide($path,$side){
  $t = [System.IO.File]::ReadAllText($path)
  $n = [regex]::Replace($t, "(?m)^side\s*=\s*['`"][^'`"]*['`"]", "side = '$side'")
  if($n -ne $t){ [System.IO.File]::WriteAllText($path, $n, $utf8); return $true }; return $false
}
function ConvertTo-JsonString($s){ return '"' + ($s -replace '\\','\\' -replace '"','\"') + '"' }

# ===== DryRun: работаем во временной копии репо =====
if($DryRun){
  $pack = Join-Path $env:TEMP 'MyVanillaPerfect-dryrun'
  if(Test-Path $pack){ Remove-Item -LiteralPath $pack -Recurse -Force }
  robocopy $realPack $pack /MIR /XD .git /NFL /NDL /NJH /NJS /NP | Out-Null
  $global:LASTEXITCODE = 0
  Write-Host "== DRY-RUN: сборка во временной копии $pack (репо и GitHub не трогаются) ==" -ForegroundColor Magenta
  $before = @{}
  Get-ChildItem $pack -Recurse -File -Force | ForEach-Object { $before[$_.FullName.Substring($pack.Length + 1)] = (Get-FileHash $_.FullName -Algorithm SHA1).Hash }
} else {
  Write-Host "== 0/7 Проверка связи с GitHub ==" -ForegroundColor Cyan
  & git -C "$pack" ls-remote origin -h 2>$null | Out-Null
  if($LASTEXITCODE -ne 0){
    Write-Host "  GitHub недоступен. Скорее всего выключен VPN/прокси ($proxy)." -ForegroundColor Red
    Write-Host "  Включи VPN и запусти скрипт заново (или -DryRun, чтобы просто посмотреть изменения)." -ForegroundColor Yellow
    exit 1
  }
  Write-Host "  OK - GitHub доступен." -ForegroundColor Green
}

Write-Host "== 1/7 Моды ==" -ForegroundColor Cyan
$pm = Join-Path $pack 'mods'
# имена уже существующих метафайлов пака запоминаем (jar -> имя .pw.toml): для дозалитых вручную модов имя не меняем,
# иначе packwiz-installer у друзей удалит и заново скачает тот же jar (запись в index.toml под другим путём)
$prevMeta = @{}
if(Test-Path $pm){
  foreach($pmf in (Get-ChildItem $pm -Filter *.pw.toml -File)){ $pmt = Get-Content $pmf.FullName -Raw; $pmfn = Get-TomlValue $pmt 'filename'; if($pmfn){ $prevMeta[$pmfn] = $pmf.Name } }
  Remove-Item "$pm\*.pw.toml" -Force -ErrorAction SilentlyContinue
} else { New-Item -ItemType Directory $pm | Out-Null }
$mods = Join-Path $inst 'mods'; $idx = Join-Path $mods '.index'
$enabled = Get-ChildItem $mods -File | Where-Object { $_.Extension -eq '.jar' }
foreach($ex in ($enabled | Where-Object { Test-AnyLike $_.Name $excludeMods })){ Write-Host "  ~ $($ex.Name) (только у тебя, в пак не идёт — `$excludeMods)" -ForegroundColor DarkGray }
$enabled = $enabled | Where-Object { -not (Test-AnyLike $_.Name $excludeMods) }
$enabledSet = @{}; $enabled | ForEach-Object { $enabledSet[$_.Name] = $true }
$covered = @{}
$knownIds = @{}   # Modrinth project-id -> jar, чтобы один мод не попал в пак двумя версиями
if(Test-Path $idx){
  Get-ChildItem $idx -Filter *.pw.toml | ForEach-Object {
    $c = Get-Content $_.FullName -Raw
    if($c -match "filename\s*=\s*'([^']+)'" -and $enabledSet.ContainsKey($Matches[1])){
      $fnIdx = $Matches[1]
      Copy-Item $_.FullName (Join-Path $pm $_.Name) -Force; $covered[$fnIdx] = $true
      if($c -match "(?m)^mod-id\s*=\s*'([^']+)'"){ $knownIds[$Matches[1]] = $fnIdx }
    }
  }
}
# дозалитые вручную моды без метаданных Prism -> ищем на Modrinth по хэшу.
# Jar, которого на Modrinth нет (например, пропатченная сборка мода), кладём в пак как обычный файл:
# packwiz раздаёт его прямо из репозитория, а старую версию у друзей удаляет сам.
$staleJars = @()
$localJars = @{}
foreach($j in $enabled){ if(-not $covered.ContainsKey($j.Name)){
  $sha1=(Get-FileHash $j.FullName -Algorithm SHA1).Hash.ToLower()
  try{ $v=Invoke-RestMethod "https://api.modrinth.com/v2/version_file/$sha1" -Headers $ua
       if($knownIds.ContainsKey($v.project_id)){
         # тот же мод уже есть в паке другой версией -> это старый jar, который забыли удалить
         Write-Host "  ! ДУБЛЬ: $($j.Name) — тот же мод, что и $($knownIds[$v.project_id]). Удали старый jar из инстанса." -ForegroundColor Yellow
         $staleJars += $j.Name; continue
       }
       # имя файла метаданных = slug проекта на Modrinth (как у packwiz), а не мешанина из имени jar
       $slug = $null; $nm = $j.BaseName
       try{ $proj = Invoke-RestMethod "https://api.modrinth.com/v2/project/$($v.project_id)" -Headers $ua; $slug = $proj.slug; $nm = $proj.title }catch{}
       if(-not $slug){ $slug=($j.BaseName -replace '[^a-zA-Z0-9]+','-').ToLower() }
       $metaName = if($prevMeta.ContainsKey($j.Name)){ $prevMeta[$j.Name] } else { "$slug.pw.toml" }
       Write-MrToml (Join-Path $pm $metaName) $j.Name $nm 'both' $v
       $knownIds[$v.project_id] = $j.Name
       Write-Host "  + $($j.Name) -> $metaName" }
  catch{
    $code = 0; try{ $code = [int]$_.Exception.Response.StatusCode }catch{}
    if($code -eq 404){
      Copy-Item $j.FullName (Join-Path $pm $j.Name) -Force
      $localJars[$j.Name] = $true
      Write-Host "  + $($j.Name) (нет на Modrinth — раздаём сам jar из пака)" -ForegroundColor DarkYellow
    } elseif(Test-Path (Join-Path $pm $j.Name)){
      # Modrinth не ответил, но этот jar уже лежит в паке — оставляем как есть
      $localJars[$j.Name] = $true
      Write-Host "  = $($j.Name) (Modrinth не ответил, HTTP $code — оставлен локальный jar)" -ForegroundColor DarkGray
    } else {
      Write-Host "  ! Modrinth не ответил по $($j.Name) (HTTP $code) — мод пропущен, запусти скрипт ещё раз" -ForegroundColor Yellow
    }
  }
}}
# локальные jar, которых больше нет в инстансе, убираем из пака
foreach($lj in (Get-ChildItem $pm -Filter *.jar -File)){
  if(-not $localJars.ContainsKey($lj.Name)){ Remove-Item $lj.FullName -Force; Write-Host "  - $($lj.Name) (локальный jar убран из пака)" -ForegroundColor DarkGray }
}
# любые CF-ссылки -> переводим на прямой Modrinth
foreach($f in (Get-ChildItem $pm -Filter *.pw.toml)){
  $c=Get-Content $f.FullName -Raw
  if(($c -match "mode\s*=\s*'url'") -and ($c -match "url\s*=\s*'https")){ continue }
  if($c -match "filename\s*=\s*'([^']+)'"){ $fn=$Matches[1] } else { continue }
  $nm = if($c -match "(?m)^name\s*=\s*'([^']+)'"){$Matches[1]}else{$fn}
  $side = if($c -match "(?m)^side\s*=\s*'([^']+)'"){$Matches[1]}else{'both'}
  $jar=Join-Path $mods $fn; if(-not(Test-Path $jar)){ continue }
  $sha1=(Get-FileHash $jar -Algorithm SHA1).Hash.ToLower()
  try{ $v=Invoke-RestMethod "https://api.modrinth.com/v2/version_file/$sha1" -Headers $ua; Write-MrToml $f.FullName $fn $nm $side $v }catch{}
}

# нормализуем side: пустое/некорректное -> 'both' (packwiz-installer принимает только client/server/both)
foreach($f in (Get-ChildItem $pm -Filter *.pw.toml)){
  $lines=Get-Content -LiteralPath $f.FullName; $changed=$false
  $o=foreach($l in $lines){ if($l -match "^\s*side\s*=\s*'([^']*)'"){ if($Matches[1] -ne 'client' -and $Matches[1] -ne 'both'){ $changed=$true; "side = 'both'" } else { $l } } else { $l } }
  if($changed){ [System.IO.File]::WriteAllText($f.FullName, (($o -join "`n")+"`n"), $utf8) }
}

# автоопределение side по Modrinth (client_side=required & server_side=unsupported -> 'client'), кэш на случай недоступности API
$sides = @{}
if(Test-Path $sideCache){ try{ (Get-Content $sideCache -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $sides[$_.Name] = $_.Value } }catch{} }
$modIds = @{}
foreach($f in (Get-ChildItem $pm -Filter *.pw.toml)){ $c = Get-Content $f.FullName -Raw; $id = Get-TomlValue $c 'mod-id'; if($id){ $modIds[$f.BaseName -replace '\.pw$',''] = $id } }
try{
  $idsJson = '[' + (($modIds.Values | Sort-Object -Unique | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']'
  $projects = Invoke-RestMethod ("https://api.modrinth.com/v2/projects?ids=" + [uri]::EscapeDataString($idsJson)) -Headers $ua
  foreach($p in $projects){ $sides[$p.id] = @{ client = $p.client_side; server = $p.server_side } }
  $dir = Split-Path $sideCache -Parent; if(-not (Test-Path $dir)){ New-Item -ItemType Directory $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($sideCache, ($sides | ConvertTo-Json -Depth 3), $utf8)
}catch{ Write-Host "  ! Modrinth /projects не ответил — side берётся из кэша $sideCache" -ForegroundColor Yellow }
$autoClient = 0
foreach($k in $modIds.Keys){
  $s = $sides[$modIds[$k]]; if(-not $s){ continue }
  if($s.client -eq 'required' -and $s.server -eq 'unsupported'){ if(Set-TomlSide (Join-Path $pm "$k.pw.toml") 'client'){ $autoClient++ } }
}
if($autoClient){ Write-Host "  side -> client по Modrinth: $autoClient модов" -ForegroundColor DarkGray }
# ручные исключения из $sideOverride
foreach($k in $sideOverride.Keys){
  $f = Join-Path $pm "$k.pw.toml"; if(-not (Test-Path $f)){ continue }
  if(Set-TomlSide $f $sideOverride[$k]){ Write-Host "  side: $k -> $($sideOverride[$k]) (override)" -ForegroundColor DarkGray }
}

# финальная проверка: один Modrinth-проект не должен встречаться в паке дважды
$byId = @{}
foreach($f in (Get-ChildItem $pm -Filter *.pw.toml)){
  $c = Get-Content $f.FullName -Raw
  if($c -match "(?m)^mod-id\s*=\s*'([^']+)'"){ $byId[$Matches[1]] += @($f.Name) }
}
$dupes = $byId.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }
if($dupes){
  foreach($d in $dupes){ Write-Host "  ! ДУБЛЬ в паке: $($d.Value -join ', ')" -ForegroundColor Red }
  Write-Host "  Публикация остановлена: удали лишние jar из инстанса и запусти скрипт снова." -ForegroundColor Red
  exit 1
}

Write-Host "== 2/7 Overrides (config/shaderpacks/emotes) ==" -ForegroundColor Cyan
$srcCfg = Join-Path $inst 'config'; $dstCfg = Join-Path $pack 'config'
$xd = @(); foreach($d in $excludeConfigDirs){ if($d -match '[\\/]'){ $xd += (Join-Path $srcCfg $d) } else { $xd += $d } }
foreach($d in @('config','shaderpacks','emotes')){
  $src=Join-Path $inst $d; $dst=Join-Path $pack $d
  if($d -eq 'config'){ robocopy $src $dst /MIR /XF $excludeConfig /XD $xd /NFL /NDL /NJH /NJS /NP | Out-Null }
  elseif($d -eq 'shaderpacks'){ robocopy $src $dst /MIR /XF *.txt *.disabled /XD "*EuphoriaPatches*" /NFL /NDL /NJH /NJS /NP | Out-Null }   # шейдеры раздаём, а .txt-настройки, выключенные .zip.disabled и распакованные папки Euphoria Patcher (мод создаёт их сам) — нет
  else { robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NP | Out-Null }   # кастомные эмоции Emotecraft
}
$global:LASTEXITCODE=0

# robocopy /MIR с /XF и /XD НЕ удаляет в назначении файлы, которые исключены, — чистим пак сами (идемпотентно)
$removed = 0
foreach($dir in (Get-ChildItem $dstCfg -Recurse -Directory -Force | Sort-Object { $_.FullName.Length } -Descending)){
  if(-not (Test-Path $dir.FullName)){ continue }
  $rel = $dir.FullName.Substring($dstCfg.Length + 1)
  $hit = $false
  foreach($d in $excludeConfigDirs){ if(($d -notmatch '[\\/]' -and $dir.Name -like $d) -or ($d -match '[\\/]' -and $rel -like $d)){ $hit = $true; break } }
  if($hit){ Remove-Item -LiteralPath $dir.FullName -Recurse -Force; $removed++ }
}
foreach($f in (Get-ChildItem $dstCfg -Recurse -File -Force)){
  if(Test-AnyLike $f.Name $excludeConfig){ Remove-Item -LiteralPath $f.FullName -Force; $removed++ }
}
if($removed){ Write-Host "  config: убрано из пака $removed исключённых файлов/папок" -ForegroundColor DarkGray }

# shaderpacks: 1) *.disabled в пак не идут; 2) если шейдер раздаётся через .pw.toml (Modrinth), такой же raw-zip из пака убираем —
# иначе один файл раздаётся дважды (raw из git + .pw.toml) и бинарник лежит в репозитории.
# Complementary r5.8.1 (raw, без .pw.toml) остаётся по решению владельца — раздаются обе версии.
$psh = Join-Path $pack 'shaderpacks'
if(Test-Path $psh){
  Get-ChildItem $psh -File -Filter *.disabled | Remove-Item -Force
  $metaNames = @{}
  foreach($m in (Get-ChildItem $psh -File -Filter *.pw.toml)){
    $t = [System.IO.File]::ReadAllText($m.FullName)
    if($t -match "(?m)^filename = '([^']+)'"){ $metaNames[$Matches[1]] = $m.Name }
  }
  foreach($z in (Get-ChildItem $psh -File | Where-Object { $_.Extension -ne '.toml' })){
    if($metaNames.ContainsKey($z.Name)){ Remove-Item -LiteralPath $z.FullName -Force; Write-Host "  shaderpacks: $($z.Name) — дубль $($metaNames[$z.Name]), raw-файл из пака убран" -ForegroundColor DarkGray }
  }
  if(-not $shipDisabledShaderMeta){
    $ish = Join-Path $inst 'shaderpacks'
    foreach($m in (Get-ChildItem $psh -File -Filter *.pw.toml)){
      $t = [System.IO.File]::ReadAllText($m.FullName)
      if($t -match "(?m)^filename = '([^']+)'"){
        $fn = $Matches[1]
        if((Test-Path (Join-Path $ish "$fn.disabled")) -or -not (Test-Path (Join-Path $ish $fn))){ Remove-Item -LiteralPath $m.FullName -Force; Write-Host "  shaderpacks: $($m.Name) — шейдер у тебя выключен, из пака убран" -ForegroundColor DarkGray }
      }
    }
  }
}

# нормализуем side у шейдеров: пустое/некорректное -> 'client' (packwiz-installer роняет пустой side)
foreach($rsd in @('shaderpacks','shaderpacks\.index')){
  $rsdir = Join-Path $pack $rsd
  if(-not (Test-Path $rsdir)){ continue }
  foreach($rsf in (Get-ChildItem $rsdir -Filter *.pw.toml -File)){
    $rst = [System.IO.File]::ReadAllText($rsf.FullName)
    $rsn = [regex]::Replace($rst, "(?m)^side = '(?!(?:client|both)')[^']*'", "side = 'client'")
    if($rsn -ne $rst){ [System.IO.File]::WriteAllText($rsf.FullName, $rsn, $utf8) }
  }
}

Write-Host "== 2b/7 Ресурспаки по списку resourcepacks.list ==" -ForegroundColor Cyan
$prp = Join-Path $pack 'resourcepacks'; $irp = Join-Path $inst 'resourcepacks'
if(-not (Test-Path $prp)){ New-Item -ItemType Directory $prp | Out-Null }
$rpEntries = @()   # @{ type; value; slug; ver; packId }
if(Test-Path $rpList){
  foreach($raw in [System.IO.File]::ReadAllLines($rpList, $utf8)){
    $line = ($raw -replace '\s+#.*$','' -replace '^#.*$','').Trim(); if(-not $line){ continue }
    if($line -notmatch '^(mr|raw|id):(.+)$'){ Write-Host "  ! непонятная строка: $raw" -ForegroundColor Yellow; continue }
    $e = @{ type = $Matches[1]; value = $Matches[2].Trim(); slug = $null; ver = $null; packId = $null }
    if($e.type -eq 'mr'){ if($e.value -match '^([^@]+)@(.+)$'){ $e.slug = $Matches[1]; $e.ver = $Matches[2] } else { $e.slug = $e.value } }
    $rpEntries += $e
  }
} else { Write-Host "  resourcepacks.list не найден — ресурспаки не раздаются" -ForegroundColor Yellow }
$keepFiles = @{}   # имя файла в resourcepacks/ пака -> оставить
foreach($e in $rpEntries){
  switch($e.type){
    'mr' {
      $meta = Join-Path $prp "$($e.slug).pw.toml"
      if(-not (Test-Path $meta)){
        Write-Host "  + packwiz mr add $($e.slug)$(if($e.ver){' @'+$e.ver})" -ForegroundColor DarkGray
        Push-Location $pack
        if($e.ver){
          try{ $proj = Invoke-RestMethod "https://api.modrinth.com/v2/project/$($e.slug)" -Headers $ua; & $pw mr add -y --project-id $proj.id --version-id $e.ver | Out-Null }
          catch{ Write-Host "  ! Modrinth не ответил по $($e.slug)" -ForegroundColor Yellow }
        } else { & $pw mr add -y $e.slug | Out-Null }
        Pop-Location
      }
      if(Test-Path $meta){
        $t = [System.IO.File]::ReadAllText($meta); $fn = Get-TomlValue $t 'filename'
        if($fn){ $e.packId = "file/$fn"; $keepFiles["$($e.slug).pw.toml"] = $true
          $rpo = Join-Path $irp "$fn.rpo"; if(Test-Path -LiteralPath $rpo){ Copy-Item -LiteralPath $rpo (Join-Path $prp "$fn.rpo") -Force; $keepFiles["$fn.rpo"] = $true } }
      } else { Write-Host "  ! $($e.slug): нет resourcepacks/$($e.slug).pw.toml — запусти resourcepacks-setup.ps1 или проверь slug" -ForegroundColor Yellow }
    }
    'raw' {
      if(Test-AnyLike $e.value $rpNever){ Write-Host "  ! $($e.value) в стоп-листе — не раздаём" -ForegroundColor Yellow; continue }
      $src = Join-Path $irp $e.value
      if(Test-Path -LiteralPath $src){
        Copy-Item -LiteralPath $src (Join-Path $prp $e.value) -Force; $keepFiles[$e.value] = $true; $e.packId = "file/$($e.value)"
        $rpo = "$src.rpo"; if(Test-Path -LiteralPath $rpo){ Copy-Item -LiteralPath $rpo (Join-Path $prp "$($e.value).rpo") -Force; $keepFiles["$($e.value).rpo"] = $true }
      } else { Write-Host "  ! raw: $($e.value) нет в $irp" -ForegroundColor Yellow }
    }
    'id' { $e.packId = $e.value }
  }
}
# всё, чего нет в списке (и стоп-лист), из resourcepacks/ пака убираем
foreach($f in (Get-ChildItem $prp -File -Force)){
  if(-not $keepFiles.ContainsKey($f.Name) -or (Test-AnyLike $f.Name $rpNever)){ Remove-Item -LiteralPath $f.FullName -Force; Write-Host "  - resourcepacks/$($f.Name) (нет в списке)" -ForegroundColor DarkGray }
}
foreach($d in (Get-ChildItem $prp -Directory -Force)){ Remove-Item -LiteralPath $d.FullName -Recurse -Force; Write-Host "  - resourcepacks/$($d.Name)/ (папка, в пак не идёт)" -ForegroundColor DarkGray }
# default-профиль Packed Packs с порядком из списка (первая строка = верхний пак) + aliases (личный VanillaTweaks друга)
$ids = @(); foreach($e in $rpEntries){ if($e.packId -and ($ids -notcontains $e.packId)){ $ids += $e.packId } }
if($ids.Count -gt 0){
  if($ids -notcontains 'vanilla'){ $ids += 'vanilla' }
  $ppDir = Join-Path $pack 'config\packed_packs\profiles\resourcepacks'; New-Item -ItemType Directory $ppDir -Force | Out-Null
  $profile = "{`n  `"locked`": false,`n  `"name`": $(ConvertTo-JsonString $rpProfileName),`n  `"overrides`": {},`n  `"packIds`": [`n" + (($ids | ForEach-Object { '    ' + (ConvertTo-JsonString $_) }) -join ",`n") + "`n  ]`n}"
  [System.IO.File]::WriteAllText((Join-Path $ppDir "$rpProfileName.profile.json"), $profile, $utf8)
  $al = ($rpAliases.Keys | ForEach-Object { '      ' + (ConvertTo-JsonString $_) + ': ' + (ConvertTo-JsonString $rpAliases[$_]) }) -join ",`n"
  $meta = "{`n  `"resourcepacks`": {`n    `"loadDefaultCondition`": `"NO_OPTIONS_OR_VERSION_FILE`",`n    `"aliases`": {`n$al`n    },`n    `"defaultProfile`": $(ConvertTo-JsonString $rpProfileName)`n  },`n  `"datapacks`": {`n    `"aliases`": {}`n  }`n}"
  [System.IO.File]::WriteAllText((Join-Path $pack 'config\packed_packs\config.meta.json'), $meta, $utf8)
  Write-Host "  раздаём $(($keepFiles.Keys | Where-Object { $_ -like '*.pw.toml' }).Count) Modrinth-паков + $(($keepFiles.Keys | Where-Object { $_ -like '*.zip' }).Count) raw; профиль '$rpProfileName': $($ids.Count) записей" -ForegroundColor DarkGray
}

Write-Host "== 3/7 Версия пака (из CHANGELOG.md) ==" -ForegroundColor Cyan
# Первый заголовок вида "## 1.1.0" в CHANGELOG.md = версия пака в pack.toml (packwiz refresh это поле не трогает)
$chg = Join-Path $pack 'CHANGELOG.md'; $ptoml = Join-Path $pack 'pack.toml'; $packVersion = $null
$prevVersion = ([regex]::Match([System.IO.File]::ReadAllText($ptoml), '(?m)^version = "([^"]*)"')).Groups[1].Value
# v1.1.2: «опубликованная» версия — из последнего КОММИТА pack.toml, а не из рабочей копии (apply-pack.ps1 бампает pack.toml заранее,
#         и без этого publish считал 1.1.0 уже опубликованной). Если git недоступен — остаётся значение из рабочей копии.
$committedToml = (& git -C $realPack show HEAD:pack.toml 2>$null) -join "`n"
if($committedToml){ $cm = [regex]::Match($committedToml, '(?m)^version = "([^"]*)"'); if($cm.Success){ $prevVersion = $cm.Groups[1].Value } }
if((Test-Path $chg) -and (Test-Path $ptoml)){
  $m = [regex]::Match([System.IO.File]::ReadAllText($chg), '(?m)^##\s*\[?v?(\d+\.\d+\.\d+)')
  if($m.Success){
    $packVersion = $m.Groups[1].Value
    $pt = [System.IO.File]::ReadAllText($ptoml)
    $pn = [regex]::Replace($pt, '(?m)^version = "[^"]*"', "version = `"$packVersion`"")
    if($pn -ne $pt){ [System.IO.File]::WriteAllText($ptoml, $pn, $utf8); Write-Host "  pack.toml: version = $packVersion (было $prevVersion)" -ForegroundColor Green } else { Write-Host "  version = $packVersion (без изменений)" -ForegroundColor DarkGray }
  } else { Write-Host "  в CHANGELOG.md нет заголовка '## x.y.z' — версия не менялась" -ForegroundColor DarkGray }
}

Write-Host "== 4/7 packwiz refresh + preserve ==" -ForegroundColor Cyan
Push-Location $pack; & $pw refresh; Pop-Location

# preserve = true для файлов класса B. packwiz refresh сохраняет флаг у существующих записей
# (core/indexfiles.go updateFileEntry меняет только hash/metafile), но новые записи появляются без него,
# а у файлов, выпавших из $preserveConfig, флаг надо снять — поэтому: refresh -> синхронизировать флаг -> refresh ещё раз.
$indexPath = Join-Path $pack 'index.toml'
if(Test-Path $indexPath){
  $lines = [System.IO.File]::ReadAllLines($indexPath)
  $out = New-Object System.Collections.Generic.List[string]
  $i = 0; $added = 0; $dropped = 0
  while($i -lt $lines.Count){
    if($lines[$i].Trim() -eq '[[files]]'){
      $block = New-Object System.Collections.Generic.List[string]; $block.Add($lines[$i]); $i++
      while($i -lt $lines.Count -and $lines[$i].Trim() -ne '' -and $lines[$i].Trim() -ne '[[files]]'){ $block.Add($lines[$i]); $i++ }
      $file = $null; $hasPreserve = $false
      foreach($b in $block){ if($b -match '^file = "(.*)"$'){ $file = $Matches[1] }; if($b -match '^preserve\s*=\s*true'){ $hasPreserve = $true } }
      $want = $false; if($file){ $want = Test-AnyLike $file $preserveConfig }
      if($want -and -not $hasPreserve){ $block.Add('preserve = true'); $added++ }
      elseif(-not $want -and $hasPreserve){ $nb = New-Object System.Collections.Generic.List[string]; foreach($b in $block){ if($b -notmatch '^preserve\s*='){ $nb.Add($b) } }; $block = $nb; $dropped++ }
      foreach($b in $block){ $out.Add($b) }
      continue
    }
    $out.Add($lines[$i]); $i++
  }
  if($added -gt 0 -or $dropped -gt 0){
    [System.IO.File]::WriteAllText($indexPath, (($out -join "`n") + "`n"), $utf8)
    Write-Host "  preserve = true: добавлен $added, снят $dropped; повторный refresh" -ForegroundColor DarkGray
    Push-Location $pack; & $pw refresh; Pop-Location
  }
  $pc = ([regex]::Matches([System.IO.File]::ReadAllText($indexPath), '(?m)^preserve = true')).Count
  Write-Host "  в index.toml файлов с preserve: $pc" -ForegroundColor DarkGray
}

# ===== 5/7 контроль: что именно раздаём =====
Write-Host "== 5/7 Контроль индекса ==" -ForegroundColor Cyan
$idxText = [System.IO.File]::ReadAllText($indexPath)
$bad = @()
foreach($p in @('config/controlify','config/voicechat/','config/packed_packs/preferences','config/packed_packs/__version','shaderpacks/.*\.disabled','config/sodium-options','resourcepacks/VanillaTweaks','resourcepacks/Patrix','resourcepacks/FreshAnimations','resourcepacks/FA+','mods/voicechat','mods/simple-voice-chat','mods/do-a-barrel-roll','mods/speed-happy-ghast')){
  if([regex]::IsMatch($idxText, '(?m)^file = "' + $p)){ $bad += $p }
}
if($bad.Count){ Write-Host "  ! В индексе есть то, чего быть не должно: $($bad -join ', ')" -ForegroundColor Red; if(-not $DryRun){ exit 1 } }
else { Write-Host "  OK: личное/удалённое в индекс не попало" -ForegroundColor Green }

if($DryRun){
  Write-Host "== DRY-RUN: сравнение с текущим репо ==" -ForegroundColor Magenta
  $after = @{}
  Get-ChildItem $pack -Recurse -File -Force | ForEach-Object { $after[$_.FullName.Substring($pack.Length + 1)] = (Get-FileHash $_.FullName -Algorithm SHA1).Hash }
  $add = @($after.Keys | Where-Object { -not $before.ContainsKey($_) } | Sort-Object)
  $del = @($before.Keys | Where-Object { -not $after.ContainsKey($_) } | Sort-Object)
  $mod = @($after.Keys | Where-Object { $before.ContainsKey($_) -and $before[$_] -ne $after[$_] } | Sort-Object)
  Write-Host "  добавится: $($add.Count), удалится: $($del.Count), изменится: $($mod.Count)"
  foreach($x in $add){ Write-Host "    + $x" -ForegroundColor Green }
  foreach($x in $del){ Write-Host "    - $x" -ForegroundColor Red }
  foreach($x in $mod){ Write-Host "    ~ $x" -ForegroundColor Yellow }
  $chgFiles = $add + $del + $mod
  if(($chgFiles | Where-Object { $_ -match '^(mods|config|resourcepacks|shaderpacks|emotes)/' }) -and $packVersion -eq $prevVersion -and -not $AllowSameVersion){
    Write-Host "  ! Версия в CHANGELOG ($packVersion) уже опубликована, а содержимое пака меняется — при настоящем publish будет стоп. Добавь запись '## x.y.z — дата'." -ForegroundColor Yellow
  }
  Write-Host "`nDry-run завершён. Временная копия: $pack" -ForegroundColor Magenta
  exit 0
}

Write-Host "== 6/7 git commit ==" -ForegroundColor Cyan
Push-Location $pack
& git add -A
$staged = @(& git diff --cached --name-only)
$contentChanged = $staged | Where-Object { $_ -match '^(mods|config|resourcepacks|shaderpacks|emotes)/' }
if($contentChanged -and $packVersion -eq $prevVersion -and -not $AllowSameVersion){
  Write-Host "  ! Содержимое пака изменилось ($(@($contentChanged).Count) файлов), а версия в CHANGELOG.md ($packVersion) уже опубликована." -ForegroundColor Red
  Write-Host "    Добавь сверху CHANGELOG.md заголовок '## x.y.z — дата' и что изменилось для друзей, затем запусти снова" -ForegroundColor Yellow
  Write-Host "    (или publish.ps1 -AllowSameVersion, если это правка без изменений для друзей)." -ForegroundColor Yellow
  & git reset -q
  Pop-Location; exit 1
}
$msg = "Update " + (Get-Date -Format 'yyyy-MM-dd HH:mm'); if($packVersion){ $msg += " (v$packVersion)" }
& git commit -m $msg
if($LASTEXITCODE -ne 0){ Write-Host "  (нет изменений — пушить нечего)" -ForegroundColor DarkGray }

Write-Host "== 7/7 git push ==" -ForegroundColor Cyan
# Staged rollout (ROADMAP F1-7): publish на ветке staging -> у друга-тестера URL .../staging/pack.toml; через 1-2 дня
#   git checkout main; git merge --ff-only staging; git push   (у всех остальных URL .../main/pack.toml).
# Push уходит в upstream ТЕКУЩЕЙ ветки - main получают все друзья сразу, staged rollout иначе невозможен.
$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
Write-Host "  ветка: $branch  ->  https://raw.githubusercontent.com/depocoder/MyVanillaPerfect/$branch/pack.toml" -ForegroundColor $(if($branch -eq 'main'){'Yellow'}else{'DarkGray'})
if($branch -eq 'main'){ Write-Host "  (main = все друзья при следующем запуске; для теста на одном друге публикуй с ветки staging)" -ForegroundColor Yellow }
if($NoPush){ Write-Host "  -NoPush: коммит есть, push не делаем. Когда проверишь: git push" -ForegroundColor Yellow }
else { & git push }
Pop-Location
Write-Host "`nГотово. Друзья получат обновление при следующем запуске игры." -ForegroundColor Green
