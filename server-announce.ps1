#Requires -Version 5.1
<#
.SYNOPSIS
  Датапак «что нового» для сервера: записи CHANGELOG.md -> сообщение в чат каждому игроку при первом заходе после обновления.

.DESCRIPTION
  Генерирует <ServerDir>\world\datapacks\mvp-changes (папка, не zip):
    * через 5 с после входа игрок получает в чат ВСЕ записи CHANGELOG новее той, что он уже видел (старые - сверху);
      увиденная версия запоминается в скорборде mvp_seen (по игроку) - повторно не показывается;
      игрок без отметки (ещё ничего не видел) получает записи новее -Baseline (1.2.2 - версия до появления датапака);
      больше -MaxEntries записей за раз не показывается;
    * /trigger changes - перечитать последнюю запись в любой момент (права оператора не нужны);
    * внизу ссылка на полный CHANGELOG на GitHub.
  Разметка CHANGELOG: **жирное** -> золотым, `код` -> жёлтым, «### подзаголовок» -> жёлтой строкой, пункты «- » -> «• ».
  Вызывается из publish.ps1 после push; руками: .\server-announce.ps1. Сервер подхватит при следующем старте
  (или командой reload в консоли сервера).
  Удалить: папку world\datapacks\mvp-changes (+ в консоли: scoreboard objectives remove mvp_seen / mvp_wait / changes).
#>
[CmdletBinding()]
param(
    [string]$ServerDir  = 'C:\Users\depo_pc\MyVanillaServer',
    [string]$Changelog  = '',                 # по умолчанию CHANGELOG.md рядом со скриптом
    [string]$Url        = 'https://github.com/depocoder/MyVanillaPerfect/blob/main/CHANGELOG.md',
    [string]$Baseline   = '1.2.2',            # игрокам без отметки показываем записи новее этой версии
    [int]$MaxEntries    = 5
)
$ErrorActionPreference = 'Stop'
if (-not $Changelog) { $Changelog = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CHANGELOG.md' }

function Get-VerCode([string]$v) { $p = $v.Split('.'); [int]$p[0] * 10000 + [int]$p[1] * 100 + [int]$p[2] }   # 1.2.3 -> 10203

# ---------- записи CHANGELOG (## x.y.z), сверху новые ----------
$lines = [IO.File]::ReadAllLines($Changelog, [Text.Encoding]::UTF8)
$entries = @()
$cur = $null
foreach ($l in $lines) {
    if ($l -match '^##\s+(\d+\.\d+\.\d+)') { $cur = [pscustomobject]@{ Ver = $Matches[1]; Code = (Get-VerCode $Matches[1]); Body = New-Object Collections.ArrayList }; $entries += $cur; continue }
    if ($l -match '^##\s') { $cur = $null; continue }
    if ($cur) { [void]$cur.Body.Add($l) }
}
if (-not $entries) { throw "В $Changelog нет заголовка '## x.y.z'" }
$latest = $entries[0]
$baseCode = Get-VerCode $Baseline
$shown = @($entries | Where-Object { $_.Code -gt $baseCode } | Select-Object -First $MaxEntries)
if (-not $shown) { $shown = @($latest) }
[array]::Reverse($shown)                     # в чате - от старой к новой

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
function Get-EntryLines($e) {
    # склеиваем продолжения пунктов (строки с отступом) в один пункт
    $items = @()
    foreach ($l in $e.Body) {
        if ($l -match '^\s*$') { continue }
        if ($l -match '^- (.*)') { $items += , @('item', $Matches[1].Trim()) }
        elseif ($l -match '^###\s+(.*)') { $items += , @('head', $Matches[1].Trim()) }
        elseif ($l -match '^\s+(.*)' -and $items.Count -and $items[-1][0] -eq 'item') { $items[-1][1] += ' ' + $Matches[1].Trim() }
        else { $items += , @('text', $l.Trim()) }
    }
    "tellraw @s {text:$(Q "━━ Что нового на сервере ($($e.Ver)) ━━"),color:`"gold`",bold:true}"
    foreach ($it in $items) {
        switch ($it[0]) {
            'item' { 'tellraw @s [{text:"• ",color:"gray"},' + ((Convert-Markdown $it[1] 'white') -join ',') + ']' }
            'head' { 'tellraw @s [' + ((Convert-Markdown $it[1] 'yellow') -join ',') + ']' }
            'text' { 'tellraw @s [' + ((Convert-Markdown $it[1] 'gray') -join ',') + ']' }
        }
    }
}
$footer = 'tellraw @s [{text:"[Все изменения]",color:"aqua",underlined:true,click_event:{action:"open_url",url:' + (Q $Url) +
    '},hover_event:{action:"show_text",value:"Открыть список изменений в браузере"}},{text:"   перечитать: ",color:"gray"},' +
    '{text:"/trigger changes",color:"yellow",click_event:{action:"suggest_command",command:"/trigger changes"}}]'

# ---------- датапак (пересоздаём function\ целиком, чтобы не оставались старые v*.mcfunction) ----------
$dp = Join-Path $ServerDir 'world\datapacks\mvp-changes'
$fn = Join-Path $dp 'data\mvp\function'
$tags = Join-Path $dp 'data\minecraft\tags\function'
if (Test-Path $fn) { Remove-Item -LiteralPath $fn -Recurse -Force }
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
    "# последняя версия $($latest.Ver) = $($latest.Code); mvp_wait - тики онлайн до показа (100 = 5 с после входа)",
    "execute as @a unless score @s mvp_seen matches $($latest.Code).. run scoreboard players add @s mvp_wait 1",
    'execute as @a[scores={mvp_wait=100..}] run function mvp:announce',
    'scoreboard players enable @a changes',
    'execute as @a[scores={changes=1..}] run function mvp:show'
)
foreach ($e in $shown) { Save (Join-Path $fn "v$($e.Code).mcfunction") @(Get-EntryLines $e) }
if (-not ($shown | Where-Object { $_.Code -eq $latest.Code })) { Save (Join-Path $fn "v$($latest.Code).mcfunction") @(Get-EntryLines $latest) }
# «unless score matches X..» истинно и для игрока без отметки -> он получит все записи новее Baseline
$announce = foreach ($e in $shown) { "execute unless score @s mvp_seen matches $($e.Code).. run function mvp:v$($e.Code)" }
Save (Join-Path $fn 'announce.mcfunction') (@($announce) + @(
    $footer,
    "scoreboard players set @s mvp_seen $($latest.Code)",
    'scoreboard players reset @s mvp_wait'
))
Save (Join-Path $fn 'show.mcfunction') @(
    "function mvp:v$($latest.Code)",
    $footer,
    'scoreboard players set @s changes 0'
)

Write-Host ("  mvp-changes: последняя {0}; при заходе показываются: {1} -> {2}" -f $latest.Ver, (($shown | ForEach-Object Ver) -join ', '), $dp) -ForegroundColor Green
Write-Host '  сервер подхватит при следующем старте (или команда reload в консоли сервера)' -ForegroundColor DarkGray
