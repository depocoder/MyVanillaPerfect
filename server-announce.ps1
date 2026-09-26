#Requires -Version 5.1
<#
.SYNOPSIS
  Датапак «что нового» для сервера: верхняя запись CHANGELOG.md -> сообщение в чат каждому игроку при первом заходе после обновления.

.DESCRIPTION
  Генерирует <ServerDir>\world\datapacks\mvp-changes (папка, не zip):
    * игрок, который ещё не видел текущую версию, через 5 с после входа получает в чат верхнюю запись CHANGELOG;
      увиденная версия запоминается в скорборде mvp_seen (по игроку) - повторно не показывается;
    * /trigger changes - перечитать в любой момент (права оператора не нужны);
    * внизу ссылка на полный CHANGELOG на GitHub.
  Разметка CHANGELOG: **жирное** -> золотым, `код` -> жёлтым, «### подзаголовок» -> жёлтой строкой, пункты «- » -> «• ».
  Вызывается из publish.ps1 после push; руками: .\server-announce.ps1. Сервер подхватит при следующем старте
  (или командой reload в консоли сервера).
  Удалить: папку world\datapacks\mvp-changes (+ в консоли: scoreboard objectives remove mvp_seen / mvp_wait / changes).
#>
[CmdletBinding()]
param(
    [string]$ServerDir = 'C:\Users\depo_pc\MyVanillaServer',
    [string]$Changelog = '',                  # по умолчанию CHANGELOG.md рядом со скриптом
    [string]$Url       = 'https://github.com/depocoder/MyVanillaPerfect/blob/main/CHANGELOG.md'
)
$ErrorActionPreference = 'Stop'
if (-not $Changelog) { $Changelog = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CHANGELOG.md' }

# ---------- верхняя запись CHANGELOG ----------
$lines = [IO.File]::ReadAllLines($Changelog, [Text.Encoding]::UTF8)
$start = -1; $ver = $null
for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^##\s+(\d+)\.(\d+)\.(\d+)') { $start = $i; $ver = $Matches; break } }
if ($start -lt 0) { throw "В $Changelog нет заголовка '## x.y.z'" }
$verText = '{0}.{1}.{2}' -f $ver[1], $ver[2], $ver[3]
$verCode = [int]$ver[1] * 10000 + [int]$ver[2] * 100 + [int]$ver[3]     # 1.2.3 -> 10203
$body = @()
for ($i = $start + 1; $i -lt $lines.Count -and $lines[$i] -notmatch '^##\s'; $i++) { $body += $lines[$i] }

# склеиваем продолжения пунктов (строки с отступом) в один пункт
$items = @()
foreach ($l in $body) {
    if ($l -match '^\s*$') { continue }
    if ($l -match '^- (.*)') { $items += , @('item', $Matches[1].Trim()) }
    elseif ($l -match '^###\s+(.*)') { $items += , @('head', $Matches[1].Trim()) }
    elseif ($l -match '^\s+(.*)' -and $items.Count -and $items[-1][0] -eq 'item') { $items[-1][1] += ' ' + $Matches[1].Trim() }
    else { $items += , @('text', $l.Trim()) }
}

# ---------- текст -> SNBT-компоненты tellraw (26.1: text/color/click_event/hover_event) ----------
function Q([string]$s) { '"' + $s.Replace('\', '\\').Replace('"', '\"') + '"' }
function Convert-Markdown([string]$s, [string]$base) {
    $parts = [regex]::Split($s, '(\*\*.+?\*\*|`.+?`)') | Where-Object { $_ -ne '' }
    foreach ($p in $parts) {
        if ($p -match '^\*\*(.+)\*\*$') { "{text:$(Q $Matches[1]),color:`"gold`"}" }
        elseif ($p -match '^`(.+)`$') { "{text:$(Q $Matches[1]),color:`"yellow`"}" }
        else { "{text:$(Q $p),color:`"$base`"}" }
    }
}
$show = @(
    "tellraw @s {text:$(Q "━━ Что нового на сервере ($verText) ━━"),color:`"gold`",bold:true}"
)
foreach ($it in $items) {
    switch ($it[0]) {
        'item' { $show += 'tellraw @s [{text:"• ",color:"gray"},' + ((Convert-Markdown $it[1] 'white') -join ',') + ']' }
        'head' { $show += 'tellraw @s [' + ((Convert-Markdown $it[1] 'yellow') -join ',') + ']' }
        'text' { $show += 'tellraw @s [' + ((Convert-Markdown $it[1] 'gray') -join ',') + ']' }
    }
}
$show += 'tellraw @s [{text:"[Все изменения]",color:"aqua",underlined:true,click_event:{action:"open_url",url:' + (Q $Url) +
    '},hover_event:{action:"show_text",value:"Открыть список изменений в браузере"}},{text:"   перечитать: ",color:"gray"},' +
    '{text:"/trigger changes",color:"yellow",click_event:{action:"suggest_command",command:"/trigger changes"}}]'
$show += 'scoreboard players set @s changes 0'

# ---------- датапак ----------
$dp = Join-Path $ServerDir 'world\datapacks\mvp-changes'
$fn = Join-Path $dp 'data\mvp\function'
$tags = Join-Path $dp 'data\minecraft\tags\function'
New-Item -ItemType Directory -Force -Path $fn, $tags | Out-Null
$utf8 = New-Object Text.UTF8Encoding $false
function Save([string]$path, [string[]]$content) { [IO.File]::WriteAllText($path, ($content -join "`n") + "`n", $utf8) }

Save (Join-Path $dp 'pack.mcmeta') @('{"pack":{"min_format":98,"max_format":999,"description":"MyVanillaPerfect: что нового (из CHANGELOG.md)"}}')
Save (Join-Path $tags 'load.json') @('{"values":["mvp:load"]}')
Save (Join-Path $tags 'tick.json') @('{"values":["mvp:tick"]}')
Save (Join-Path $fn 'load.mcfunction') @(
    '# сгенерировано server-announce.ps1 - не править руками',
    'scoreboard objectives add mvp_seen dummy',
    'scoreboard objectives add mvp_wait dummy',
    'scoreboard objectives add changes trigger'
)
Save (Join-Path $fn 'tick.mcfunction') @(
    "# версия $verText = $verCode; mvp_wait - тики онлайн до показа (100 = 5 с после входа)",
    "execute as @a unless score @s mvp_seen matches $verCode run scoreboard players add @s mvp_wait 1",
    'execute as @a[scores={mvp_wait=100..}] run function mvp:announce',
    'scoreboard players enable @a changes',
    'execute as @a[scores={changes=1..}] run function mvp:show'
)
Save (Join-Path $fn 'announce.mcfunction') @(
    'function mvp:show',
    "scoreboard players set @s mvp_seen $verCode",
    'scoreboard players reset @s mvp_wait'
)
Save (Join-Path $fn 'show.mcfunction') $show

Write-Host "  mvp-changes: версия $verText, строк в чате: $($show.Count - 1) -> $dp" -ForegroundColor Green
Write-Host '  сервер подхватит при следующем старте (или команда reload в консоли сервера)' -ForegroundColor DarkGray
