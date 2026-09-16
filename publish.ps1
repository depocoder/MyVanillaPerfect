# publish.ps1 — обновить пак из инстанса и залить друзьям одной командой.
# Запуск: ПКМ по файлу -> "Run with PowerShell"
#   или в терминале:  powershell -ExecutionPolicy Bypass -File publish.ps1
#
# Что делает: пересобирает метаданные модов из твоего инстанса (с прямыми ссылками
# на Modrinth; jar без Modrinth-версии, например пропатченный мод, кладётся в пак как файл),
# синхронит config/shaderpacks (ресурспаки не раздаём), обновляет packwiz-индекс
# и пушит в GitHub. Друзья получат обновление при следующем запуске игры.

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

# ===== ПУТИ (поменяй, если перенесёшь инстанс/packwiz) =====
$inst = "C:\Users\depo_pc\AppData\Roaming\PrismLauncher\instances\Fabulously Optimized(4)\minecraft"
$pack = $PSScriptRoot                       # папка этого скрипта = папка пака
$pw   = "C:\Users\depo_pc\go\bin\packwiz.exe"
$ua   = @{ 'User-Agent' = 'fo-pack/1.0 (publish.ps1)' }
$excludeConfig = @('sodium-options.json','iris.properties','emotecraft.json','shulkerboxtooltip_mp_ender_chest_cache.dat','litematica.json*','voicechat-client.properties')  # личная графика/шейдер/колесо эмоций/кэши/хоткеи Litematica/микрофон войс-чата — не раздаём
$excludeConfigDirs = @('litematica','punchy')  # личные настройки Punchy и данные Litematica по мирам — не раздаём
$proxy = 'http://127.0.0.1:20808'  # локальный прокси/VPN для доступа к GitHub (поменяй порт, если у тебя другой)

# Прокси задаём ТОЛЬКО для этой сессии скрипта; систему не трогаем, после выхода сбросится сам.
# (Само приложение-VPN при этом должно быть запущено — скрипт задаёт лишь адрес.)
$env:HTTP_PROXY  = $proxy
$env:HTTPS_PROXY = $proxy

function Write-MrToml($path,$fn,$nm,$side,$v){
  $file = $v.files | Where-Object { $_.filename -eq $fn } | Select-Object -First 1
  if(-not $file){ $file = $v.files | Where-Object { $_.primary } | Select-Object -First 1 }
  if(-not $file){ $file = $v.files | Select-Object -First 1 }
  $enc = New-Object System.Text.UTF8Encoding($false)
  $t = "filename = '$fn'`nname = '$nm'`nside = '$side'`n`n[download]`nhash-format = 'sha512'`nhash = '$($file.hashes.sha512)'`nmode = 'url'`nurl = '$($file.url)'`n`n[update.modrinth]`nmod-id = '$($v.project_id)'`nversion = '$($v.id)'`n"
  [System.IO.File]::WriteAllText($path,$t,$enc)
}

Write-Host "== 0/5 Проверка связи с GitHub ==" -ForegroundColor Cyan
& git -C "$pack" ls-remote origin -h 2>$null | Out-Null
if($LASTEXITCODE -ne 0){
  Write-Host "  GitHub недоступен. Скорее всего выключен VPN/прокси (127.0.0.1:20808)." -ForegroundColor Red
  Write-Host "  Включи VPN и запусти скрипт заново." -ForegroundColor Yellow
  exit 1
}
Write-Host "  OK - GitHub доступен." -ForegroundColor Green

Write-Host "== 1/5 Моды ==" -ForegroundColor Cyan
$pm = Join-Path $pack 'mods'
if(Test-Path $pm){ Remove-Item "$pm\*.pw.toml" -Force -ErrorAction SilentlyContinue } else { New-Item -ItemType Directory $pm | Out-Null }
$mods = Join-Path $inst 'mods'; $idx = Join-Path $mods '.index'
$enabled = Get-ChildItem $mods -File | Where-Object { $_.Extension -eq '.jar' }
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
       $slug=($j.BaseName -replace '[^a-zA-Z0-9]+','-').ToLower()
       Write-MrToml (Join-Path $pm "$slug.pw.toml") $j.Name $j.BaseName 'both' $v
       $knownIds[$v.project_id] = $j.Name
       Write-Host "  + $($j.Name)" }
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
  if($changed){ [System.IO.File]::WriteAllText($f.FullName, (($o -join "`n")+"`n"), (New-Object System.Text.UTF8Encoding($false))) }
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

Write-Host "== 2/5 Overrides (config/shaderpacks/emotes) ==" -ForegroundColor Cyan
# resourcepacks намеренно НЕ раздаём: каждый ставит свои
foreach($d in @('config','shaderpacks','emotes')){
  $src=Join-Path $inst $d; $dst=Join-Path $pack $d
  if($d -eq 'config'){ robocopy $src $dst /MIR /XF $excludeConfig /XD $excludeConfigDirs /NFL /NDL /NJH /NJS /NP | Out-Null }
  elseif($d -eq 'shaderpacks'){ robocopy $src $dst /MIR /XF *.txt /XD "*EuphoriaPatches*" /NFL /NDL /NJH /NJS /NP | Out-Null }   # шейдеры раздаём, а .txt-настройки и распакованные папки Euphoria Patcher (мод создаёт их сам) — нет
  else { robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NP | Out-Null }   # кастомные эмоции Emotecraft
}
$global:LASTEXITCODE=0

# нормализуем side у шейдеров: пустое/некорректное -> 'client' (packwiz-installer роняет пустой side)
$rsUtf8 = New-Object System.Text.UTF8Encoding($false)
foreach($rsd in @('shaderpacks','shaderpacks\.index')){
  $rsdir = Join-Path $pack $rsd
  if(-not (Test-Path $rsdir)){ continue }
  foreach($rsf in (Get-ChildItem $rsdir -Filter *.pw.toml -File)){
    $rst = [System.IO.File]::ReadAllText($rsf.FullName)
    $rsn = [regex]::Replace($rst, "(?m)^side = '(?!(?:client|both)')[^']*'", "side = 'client'")
    if($rsn -ne $rst){ [System.IO.File]::WriteAllText($rsf.FullName, $rsn, $rsUtf8) }
  }
}

Write-Host "== 3/5 packwiz refresh ==" -ForegroundColor Cyan
Push-Location $pack; & $pw refresh; Pop-Location

Write-Host "== 4/5 git commit ==" -ForegroundColor Cyan
Push-Location $pack
& git add -A
& git commit -m ("Update " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
if($LASTEXITCODE -ne 0){ Write-Host "  (нет изменений — пушить нечего)" -ForegroundColor DarkGray }

Write-Host "== 5/5 git push ==" -ForegroundColor Cyan
& git push
Pop-Location
Write-Host "`nГотово. Друзья получат обновление при следующем запуске игры." -ForegroundColor Green
