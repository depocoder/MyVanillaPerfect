#!/usr/bin/env node
// check-upgrade.js v2.2 (2026-09-17) — готовность пака к заданной версии Minecraft (по Modrinth API), раздельные ворота сервер/клиент.
// ВОРОТА ПРЕДВАРИТЕЛЬНЫЕ: 100 % серверных / 90 % клиентских — умолчания из REMAINING-DECISIONS п.9; окончательный критерий владелец
// выбирает при миграции (решение -17c п.9). Дополнительно печатается общий показатель «готово X из Y (Z %)» — простой критерий CLAUDE.md (>= 90 %).
// Лежит в корне репозитория пака, читает mods/*.pw.toml (только записи с [update.modrinth]).
//
//   node check-upgrade.js 26.3                          — ворота: серверные (не-снимаемые) 100 % + клиентские >= 90 %
//   node check-upgrade.js 26.3 --gate 90                — клиентский порог в % (предварительно 90; окончательно — при миграции)
//   node check-upgrade.js 26.3 --server-gate 100        — серверный порог в % (предварительно 100; окончательно — при миграции)
//   node check-upgrade.js 26.1.2 [--current]            — РЕЖИМ ТЕКУЩЕЙ ВЕРСИИ (включается сам, если цель = minecraft из pack.toml):
//                                                         правила NEW_FILE и «серверному нужен release» НЕ применяются (иначе D&T x10 и
//                                                         emotecraft alpha дают ложное «ворота НЕ выполнены»); итог = список модов без
//                                                         версии под текущую MC; код выхода 0, если таких нет
//   node check-upgrade.js 26.3 --removable a,b          — серверные моды «снимаемые на время апгрейда» (D8): не блокируют
//   node check-upgrade.js 26.3 --new-file a,b           — моды, которым нужен НОВЫЙ файл, а не ретег (D&T x10, speed-happy-ghast):
//                                                         готов только если версия опубликована после --since и её id != текущему в pw.toml
//   node check-upgrade.js 26.3 --since 2026-09-15       — дата выхода целевой версии (по умолчанию для 26.3)
//   node check-upgrade.js 26.3 --server-mods C:\Users\depo_pc\MyVanillaServer\mods   — «серверный» = jar реально стоит на сервере (точнее, чем Modrinth server_side)
//   node check-upgrade.js 26.3 --extra-server spark,boids,structure-explorer
//                                                       — серверные моды вне пака (Modrinth slug/id), считаются в серверные ворота
//   node check-upgrade.js 26.3 --allow-prerelease       — засчитывать alpha/beta и для серверных модов (по умолчанию: серверным нужен release)
//   node check-upgrade.js 26.3 --json out.json --md docs/readiness.md --ignore a,b --all [--pack <dir>]
//
// Классификация «серверный»: side в pw.toml != 'client' И Modrinth server_side != 'unsupported' (или мод из --extra-server).
// Код выхода: 0 — оба ворота выполнены; 1 — нет; 2 — ошибка. Скрипт НЕ решает за владельца: ворота = скрипт И чистый
// дельта-тест на копии мира (ROADMAP F4-3).
// Требуется Node.js >= 18 (fetch). Modrinth просит указывать User-Agent — см. UA ниже.
'use strict';
const fs = require('fs'), path = require('path');

const argv = process.argv.slice(2);
const target = argv.find(a => !a.startsWith('--') && !(argv[argv.indexOf(a) - 1] || '').startsWith('--'));
if (!target) { console.error('usage: node check-upgrade.js <mc-version> [--gate N] [--server-gate N] [--removable a,b] [--new-file a,b] [--since YYYY-MM-DD] [--extra-server a,b] [--allow-prerelease] [--json file] [--md file] [--ignore a,b] [--all]'); process.exit(2); }
const opt = (name, def) => { const i = argv.indexOf('--' + name); return i >= 0 && argv[i + 1] !== undefined ? argv[i + 1] : def; };
const list_ = (name) => (opt(name, '') || '').split(',').map(s => s.trim()).filter(Boolean);
const GATE = Number(opt('gate', 90));
const SERVER_GATE = Number(opt('server-gate', 100));
const JSON_OUT = opt('json', null);
const MD_OUT = opt('md', null);
const SHOW_ALL = argv.includes('--all');
const PACK_ROOT = opt('pack', __dirname);
// версия Minecraft пака из pack.toml ([versions] minecraft = "26.1.2") — для режима текущей версии
let PACK_MC = null;
try { PACK_MC = (fs.readFileSync(path.join(PACK_ROOT, 'pack.toml'), 'utf8').match(/^minecraft\s*=\s*['"]([^'"]+)['"]/m) || [])[1] || null; } catch (e) { /* pack.toml не найден — режим только по --current */ }
const CURRENT = argv.includes('--current') || (PACK_MC !== null && target === PACK_MC);
const ALLOW_PRE = argv.includes('--allow-prerelease') || CURRENT;
const RELEASE_DATES = { '26.3': '2026-09-15', '26.2': '2026-06-16', '26.1': '2026-03-24' };
const SINCE = opt('since', RELEASE_DATES[target] || '1970-01-01');
// Моды, которые при апгрейде ЗАМЕНЯЮТСЯ другим проектом, в гейт не считаем (их «готовность» = готовность замены):
//   fabrishot -> renice-shot (26.3: 1.1.0+mc26.3), world-play-time -> world-play-time-reborn
const DEFAULT_IGNORE = ['fabrishot', 'world-play-time'];  // world-play-time после замены на world-play-time-reborn из пака исчезает сам
const IGNORE = new Set(DEFAULT_IGNORE.concat(list_('ignore')));
// D8 (по умолчанию): серверные моды без следа в мире — снимаются на время апгрейда, не блокируют.
const DEFAULT_REMOVABLE = ['voxy-server-side', 'diagonal-fences', 'horseman', 'sessility', 'boids', 'structure-explorer', 'spark', 'tabtps', 'ledger', 'villager-death-messages', 'rightclickharvest', 'debugify', 'appleskin', 'better-stats', 'itemstats', 'pickup-notifications', 'ping-wheel', 'emotecraft', 'patpat', 'inventory-sorting', 'easy-shulker-boxes', 'no-chat-reports', 'krypton', 'c2me-fabric', 'world-play-time-reborn', 'chat-heads', 'cosy-critters', 'fallingleaves', 'subtle-effects']  // v2.1: do-a-barrel-roll/simple-voice-chat/speed-happy-ghast удалены из пака 17.09; новые «необязательные при переезде» моды помечены снимаемыми  // visual-workbench / eg-invisible-frames НЕ снимаемые: block entity / новый предмет в мире;
const REMOVABLE = new Set(list_('removable').length ? list_('removable') : DEFAULT_REMOVABLE);
// Ретег не спасёт — нужен новый файл (installedJudge: SpawnerData count / configured_feature в 26.3):
const DEFAULT_NEW_FILE = ['dungeons-and-taverns', 'dungeons-and-taverns-ancient-city-overhaul', 'dungeons-and-taverns-desert-temple-overhaul', 'dungeons-and-taverns-jungle-temple-overhaul', 'dungeons-and-taverns-nether-fortress-overhaul', 'dungeons-and-taverns-ocean-monument-overhaul', 'dungeons-and-taverns-pillager-outpost-overhaul', 'dungeons-and-taverns-stronghold-overhaul', 'dungeons-and-taverns-swamp-hut-overhaul', 'dungeons-and-taverns-woodland-mansion-overhaul', 'dungeons-and-taverns-mineshaft-overhaul', 'towns-and-towers', 'structory-towers'];
const NEW_FILE = new Set(list_('new-file').length ? list_('new-file') : DEFAULT_NEW_FILE);
const EXTRA_SERVER = list_('extra-server');
// --server-mods <file|dir>: реальный список jar сервера (D:\MCBackups\server-meta\mods-list.txt из backup.ps1 или папка MyVanillaServer\mods).
// Если задан — «серверный» = jar из пака стоит на сервере (по filename), а не догадка по Modrinth server_side.
const SERVER_MODS_SRC = opt('server-mods', null);
let SERVER_FILES = null;
if (SERVER_MODS_SRC) {
  const st = fs.statSync(SERVER_MODS_SRC);
  const names = st.isDirectory() ? fs.readdirSync(SERVER_MODS_SRC).filter(f => f.endsWith('.jar')) : fs.readFileSync(SERVER_MODS_SRC, 'utf8').split(/\r?\n/).map(x => x.trim()).filter(Boolean);
  SERVER_FILES = new Set(names.map(n => n.toLowerCase()));
}

const PACK = path.join(PACK_ROOT, 'mods');   // --pack <dir> — корень репо пака, если скрипт лежит не там
const UA = { 'User-Agent': 'MyVanillaPerfect/check-upgrade (github.com/depocoder/MyVanillaPerfect)' };
const now = new Date();
const days = (a, b) => Math.round((new Date(a) - new Date(b)) / 86400000);

const mods = fs.readdirSync(PACK).filter(f => f.endsWith('.pw.toml')).map(f => {
  const t = fs.readFileSync(path.join(PACK, f), 'utf8');
  const g = re => (t.match(re) || [])[1];
  return { slug: f.replace('.pw.toml', ''), name: g(/^name = ['"](.*)['"]/m), id: g(/^mod-id = ['"](.*)['"]/m), cur: g(/^version = ['"](.*)['"]/m), file: g(/^filename = ['"](.*)['"]/m), side: g(/^side = ['"](.*)['"]/m) || 'both', extra: false };
});
const noModrinth = mods.filter(m => !m.id);
const list = mods.filter(m => m.id && !IGNORE.has(m.slug));

async function j(url) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const r = await fetch(url, { headers: UA });
    if (r.status === 429) { await new Promise(res => setTimeout(res, 2000 * (attempt + 1))); continue; }
    if (!r.ok) throw new Error(r.status + ' ' + url);
    return r.json();
  }
  throw new Error('429 (rate limit) ' + url);
}
// "26.3" считаем готовым и при точных версиях "26.3.1" и т.п.; "26.1" — 26.1/26.1.1/26.1.2
const matches = (gv, t) => gv === t || gv.startsWith(t + '.');

(async () => {
  // серверные моды вне пака (spark, boids, structure-explorer ...) — по slug через /v2/project/<slug>
  for (const s of EXTRA_SERVER) {
    try { const p = await j('https://api.modrinth.com/v2/project/' + encodeURIComponent(s)); list.push({ slug: p.slug, name: p.title, id: p.id, cur: null, file: null, side: 'server', extra: true }); }
    catch (e) { console.error('! extra-server', s, e.message); }
  }
  const meta = {};
  for (let i = 0; i < list.length; i += 40) {
    const ids = list.slice(i, i + 40).map(m => m.id);
    try { for (const p of await j('https://api.modrinth.com/v2/projects?ids=' + encodeURIComponent(JSON.stringify(ids)))) meta[p.id] = p; }
    catch (e) { console.error('! projects batch:', e.message); }
  }
  const rows = [];
  for (const m of list) {
    const p = meta[m.id] || {};
    let vers = [];
    try { vers = await j(`https://api.modrinth.com/v2/project/${m.id}/version`); } catch (e) { console.error('!', m.slug, e.message); }
    vers = vers.filter(v => (v.loaders || []).includes('fabric')).sort((a, b) => b.date_published.localeCompare(a.date_published));
    const forTarget = vers.filter(v => v.game_versions.some(gv => matches(gv, target)));
    const isServer = m.extra || (SERVER_FILES ? !!(m.file && SERVER_FILES.has(m.file.toLowerCase())) : (m.side !== 'client' && p.server_side !== 'unsupported'));
    const removable = isServer && REMOVABLE.has(m.slug);
    const needNewFile = !CURRENT && NEW_FILE.has(m.slug);   // в режиме текущей версии установленный файл и есть «новый»
    let pool = forTarget;
    if (needNewFile) pool = pool.filter(v => v.date_published.slice(0, 10) >= SINCE && v.id !== m.cur);
    const release = pool.find(v => v.version_type === 'release');
    const best = release || (isServer && !ALLOW_PRE ? null : pool[0]);
    const retagOnly = needNewFile && forTarget.length > 0 && !best;
    const preOnly = !release && pool.length > 0 && isServer && !ALLOW_PRE;
    const latest = vers[0];
    rows.push({
      slug: m.slug, name: m.name || p.title, id: m.id, side: m.side, file: m.file, extra: m.extra,
      client_side: p.client_side, server_side: p.server_side, source_url: p.source_url || '', license: (p.license || {}).id || '',
      is_server: isServer, removable, need_new_file: needNewFile,
      ready: !!best,
      reason: best ? 'ok' : (retagOnly ? 'retag-only (нужен новый файл)' : preOnly ? 'только alpha/beta (серверному нужен release)' : 'нет версии'),
      target_version: best ? { ver: best.version_number, id: best.id, type: best.version_type, date: best.date_published.slice(0, 10) } : null,
      latest_version: latest ? latest.version_number : null, latest_date: latest ? latest.date_published.slice(0, 10) : null,
      latest_game: latest ? latest.game_versions.slice(-1)[0] : null,
      releases_12m: vers.filter(v => days(now, v.date_published) <= 365).length,
      days_since_last_release: latest ? days(now, latest.date_published) : null,
    });
    process.stderr.write('.');
  }
  process.stderr.write('\n');
  const pct = (a, b) => b ? Math.round(1000 * a / b) / 10 : 100;
  const srvBlocking = rows.filter(r => r.is_server && !r.removable);
  const srvRemovable = rows.filter(r => r.is_server && r.removable);
  const cli = rows.filter(r => !r.is_server);
  const srvReady = srvBlocking.filter(r => r.ready), srvMissing = srvBlocking.filter(r => !r.ready);
  const cliReady = cli.filter(r => r.ready), cliMissing = cli.filter(r => !r.ready);
  const srvPct = pct(srvReady.length, srvBlocking.length), cliPct = pct(cliReady.length, cli.length);
  const allReady = rows.filter(r => r.ready);
  const srvOk = srvPct >= SERVER_GATE, cliOk = cliPct >= GATE;
  const out = [];
  out.push(`Minecraft ${target} (проверено ${now.toISOString().slice(0, 10)}, версии считаются с ${SINCE})${CURRENT ? ' — РЕЖИМ ТЕКУЩЕЙ ВЕРСИИ (pack.toml: ' + PACK_MC + '; ворота не применяются)' : ''}`);
  out.push(`  Серверные блокирующие: готово ${srvReady.length} из ${srvBlocking.length} (${srvPct} %), ворота ${SERVER_GATE} % — ${srvOk ? 'OK' : 'ещё рано'}`);
  out.push(`  Серверные снимаемые (D8, не блокируют): готово ${srvRemovable.filter(r => r.ready).length} из ${srvRemovable.length}`);
  out.push(`  Клиентские: готово ${cliReady.length} из ${cli.length} (${cliPct} %), ворота ${GATE} % — ${cliOk ? 'OK' : 'ещё рано'}`);
  const allPct = pct(allReady.length, rows.length);
  out.push(`  Всего: готово ${allReady.length} из ${rows.length} (${allPct} %) — простой критерий CLAUDE.md >= 90 % — ${allPct >= 90 ? 'OK' : 'ещё рано'}`);
  if (CURRENT) out.push(`  ИТОГ (текущая версия): модов без версии под ${target}: ${rows.length - allReady.length}${rows.length - allReady.length ? ' — см. списки ниже' : ' — всё на месте'}`);
  else out.push(`  ИТОГ: ${srvOk && cliOk ? 'ворота выполнены (предварительные 100 %/90 %) — дальше дельта-тест на копии (F4-3); окончательный критерий — решение владельца при миграции' : 'ворота НЕ выполнены (предварительные 100 %/90 %; окончательный критерий — при миграции)'}`);
  if (IGNORE.size) out.push(`  (не считаются: ${[...IGNORE].join(', ')})`);
  if (noModrinth.length) out.push(`  (без Modrinth-метаданных, проверь руками: ${noModrinth.map(m => m.slug).join(', ')})`);
  const fmt = r => `  ${r.slug.padEnd(46)} ${r.reason.padEnd(42)} последняя ${String(r.latest_version).padEnd(24)} ${r.latest_date} (${r.latest_game}, ${r.days_since_last_release} дн., ${r.releases_12m} рел./год)`;
  const bySt = (a, b) => (b.days_since_last_release || 0) - (a.days_since_last_release || 0);
  if (srvMissing.length) { out.push(`\nСерверные БЛОКЕРЫ без ${target} (${srvMissing.length}):`); srvMissing.sort(bySt).forEach(r => out.push(fmt(r))); }
  const remMissing = srvRemovable.filter(r => !r.ready);
  if (remMissing.length) { out.push(`\nСерверные снимаемые без ${target} (${remMissing.length}) — снять на время апгрейда, вернуть позже:`); remMissing.sort(bySt).forEach(r => out.push(fmt(r))); }
  if (cliMissing.length) { out.push(`\nКлиентские без ${target} (${cliMissing.length}) — временно убрать из пака:`); cliMissing.sort(bySt).forEach(r => out.push(fmt(r))); }
  const retag = rows.filter(r => r.reason.startsWith('retag'));
  if (retag.length) out.push(`\nРетег без нового файла (${retag.length}): ${retag.map(r => r.slug).join(', ')}`);
  if (SHOW_ALL && allReady.length) { out.push(`\nГотовы (${allReady.length}):`); for (const r of allReady) out.push(`  ${r.slug.padEnd(46)} ${r.target_version.ver} (${r.target_version.type}, ${r.target_version.date})${r.is_server ? '  [server' + (r.removable ? ', removable' : '') + ']' : ''}`); }
  const beta = allReady.filter(r => r.target_version.type !== 'release');
  if (beta.length) out.push(`\nГотовы только beta/alpha (${beta.length}): ${beta.map(r => r.slug).join(', ')}`);
  console.log(out.join('\n'));
  const result = { target, checked: now.toISOString().slice(0, 10), since: SINCE, gate: GATE, server_gate: SERVER_GATE, current_mode: CURRENT, pack_minecraft: PACK_MC, overall: { total: rows.length, ready: allReady.length, percent: allPct }, server_blocking: { total: srvBlocking.length, ready: srvReady.length, percent: srvPct, ok: srvOk }, server_removable: { total: srvRemovable.length, ready: srvRemovable.filter(r => r.ready).length }, client: { total: cli.length, ready: cliReady.length, percent: cliPct, ok: cliOk }, ok: srvOk && cliOk, ignored: [...IGNORE], removable: [...REMOVABLE], new_file: [...NEW_FILE], no_modrinth: noModrinth.map(m => m.slug), rows };
  if (JSON_OUT) { fs.writeFileSync(JSON_OUT, JSON.stringify(result, null, 1)); console.log(`\nJSON: ${JSON_OUT}`); }
  if (MD_OUT) {
    const md = [`# Готовность к ${target} — ${result.checked}`, '', `Серверные блокеры: ${srvReady.length}/${srvBlocking.length} (${srvPct} %, ворота ${SERVER_GATE} %) — ${srvOk ? 'OK' : 'рано'}  `, `Клиентские: ${cliReady.length}/${cli.length} (${cliPct} %, ворота ${GATE} %) — ${cliOk ? 'OK' : 'рано'}`, '', '| Мод | Класс | Готов | Причина | Версия под ' + target + ' | Последняя |', '|---|---|---|---|---|---|'];
    for (const r of rows.sort((a, b) => (a.is_server === b.is_server ? 0 : a.is_server ? -1 : 1) || a.slug.localeCompare(b.slug)))
      md.push(`| ${r.slug} | ${r.is_server ? (r.removable ? 'server (снимаемый)' : 'server (блокер)') : 'client'} | ${r.ready ? 'да' : 'нет'} | ${r.reason} | ${r.target_version ? r.target_version.ver + ' (' + r.target_version.type + ', ' + r.target_version.date + ')' : '—'} | ${r.latest_version} (${r.latest_date}) |`);
    fs.writeFileSync(MD_OUT, md.join('\n') + '\n'); console.log(`Markdown: ${MD_OUT}`);
  }
  process.exit(CURRENT ? (allReady.length === rows.length ? 0 : 1) : (srvOk && cliOk ? 0 : 1));
})().catch(e => { console.error(e); process.exit(2); });
