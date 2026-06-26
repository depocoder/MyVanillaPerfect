# publish.ps1 — обновить пак из инстанса и залить друзьям одной командой.
# Запуск: ПКМ по файлу -> "Run with PowerShell"
#   или в терминале:  powershell -ExecutionPolicy Bypass -File publish.ps1
#
# Что делает: пересобирает метаданные модов из твоего инстанса (с прямыми ссылками
# на Modrinth), синхронит config/resourcepacks/shaderpacks, обновляет packwiz-индекс
# и пушит в GitHub. Друзья получат обновление при следующем запуске игры.

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

# ===== ПУТИ (поменяй, если перенесёшь инстанс/packwiz) =====
$inst = "C:\Users\depo_pc\AppData\Roaming\PrismLauncher\instances\Fabulously Optimized(4)\minecraft"
$pack = $PSScriptRoot                       # папка этого скрипта = папка пака
$pw   = "C:\Users\depo_pc\go\bin\packwiz.exe"
$ua   = @{ 'User-Agent' = 'fo-pack/1.0 (publish.ps1)' }
$excludeConfig = @('sodium-options.json','iris.properties')  # личная графика/шейдер — не раздаём

function Write-MrToml($path,$fn,$nm,$side,$v){
  $file = $v.files | Where-Object { $_.filename -eq $fn } | Select-Object -First 1
  if(-not $file){ $file = $v.files | Where-Object { $_.primary } | Select-Object -First 1 }
  if(-not $file){ $file = $v.files | Select-Object -First 1 }
  $enc = New-Object System.Text.UTF8Encoding($false)
  $t = "filename = '$fn'`nname = '$nm'`nside = '$side'`n`n[download]`nhash-format = 'sha512'`nhash = '$($file.hashes.sha512)'`nmode = 'url'`nurl = '$($file.url)'`n`n[update.modrinth]`nmod-id = '$($v.project_id)'`nversion = '$($v.id)'`n"
  [System.IO.File]::WriteAllText($path,$t,$enc)
}

Write-Host "== 1/5 Моды ==" -ForegroundColor Cyan
$pm = Join-Path $pack 'mods'
if(Test-Path $pm){ Remove-Item "$pm\*.pw.toml" -Force -ErrorAction SilentlyContinue } else { New-Item -ItemType Directory $pm | Out-Null }
$mods = Join-Path $inst 'mods'; $idx = Join-Path $mods '.index'
$enabled = Get-ChildItem $mods -File | Where-Object { $_.Extension -eq '.jar' }
$enabledSet = @{}; $enabled | ForEach-Object { $enabledSet[$_.Name] = $true }
$covered = @{}
if(Test-Path $idx){
  Get-ChildItem $idx -Filter *.pw.toml | ForEach-Object {
    $c = Get-Content $_.FullName -Raw
    if($c -match "filename\s*=\s*'([^']+)'" -and $enabledSet.ContainsKey($Matches[1])){
      Copy-Item $_.FullName (Join-Path $pm $_.Name) -Force; $covered[$Matches[1]] = $true
    }
  }
}
# дозалитые вручную моды без метаданных Prism -> ищем на Modrinth по хэшу
foreach($j in $enabled){ if(-not $covered.ContainsKey($j.Name)){
  $sha1=(Get-FileHash $j.FullName -Algorithm SHA1).Hash.ToLower()
  try{ $v=Invoke-RestMethod "https://api.modrinth.com/v2/version_file/$sha1" -Headers $ua
       $slug=($j.BaseName -replace '[^a-zA-Z0-9]+','-').ToLower()
       Write-MrToml (Join-Path $pm "$slug.pw.toml") $j.Name $j.BaseName 'both' $v
       Write-Host "  + $($j.Name)" }
  catch{ Write-Host "  ! НЕ найден на Modrinth: $($j.Name) — добавь вручную (packwiz cf add / url add)" -ForegroundColor Yellow }
}}
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

Write-Host "== 2/5 Overrides (config/resourcepacks/shaderpacks) ==" -ForegroundColor Cyan
foreach($d in @('config','resourcepacks')){   # shaderpacks НЕ раздаём — у каждого свои (разное железо)
  $src=Join-Path $inst $d; $dst=Join-Path $pack $d
  if($d -eq 'config'){ robocopy $src $dst /MIR /XF $excludeConfig /NFL /NDL /NJH /NJS /NP | Out-Null }
  else { robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NP | Out-Null }
}
$global:LASTEXITCODE=0

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
