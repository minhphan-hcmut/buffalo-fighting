# Task 4 — bằng chứng mô phỏng và readiness build/demo (17/11/2026)

## Phạm vi và kết luận

- Worker chỉ thu thập bằng chứng; đã đọc toàn bộ `AGENTS.md`, approved spec/plan ngày 17/11, `tools/balance_sim.gd`, `tests/balance_sim_smoke_test.gd`, README, export preset và CSV credits trước khi dùng/audit.
- **100 trận chính, 25 cells = 5 level × 5 profile, 4 trận/cell**, NORMAL làm đối chứng với EASY/EASY_PLUS/NORMAL/NORMAL_PLUS/HARD. Mỗi cell chạy hai trận ở mỗi hướng vật lý; không dùng override balance. Smoke, pilot và một lần lặp HARD bổ sung, không cộng vào mẫu chính.
- **Không có thay đổi balance nào được biện minh từ mẫu nhỏ này.** Không sửa gameplay/tests/config/GDD; không commit. Main giữ quyền quyết định tuning/release.
- Đây là AI-v-AI headless trên controller thật, **không phải human playtest**, không phải đo FPS, không phải bản build độc lập. Task3 đã được main nhận; R1 live dual-window LAN còn mở và không được điều tra/chạy lại trong task này.
- Build/export **bị chặn vì không có templates 4.7.2.stable**; không export, không cài/download. Không tuyên bố đạt release/demo.

## Môi trường, cô lập, artifact

- Root: `/home/konits/projects/ltrgame/buffalo-fighting`.
- Runtime: `/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64`; `--version` trả `4.7.2.stable.official.ed1daf0bf`.
- Máy: Linux 7.3.3-200.fc44.x86_64, glibc 2.43; AMD Ryzen 7 8845H, 16 logical CPUs. Headless, không renderer/hardware FPS claim.
- XDG riêng cho mọi simulation/smoke: `XDG_DATA_HOME=/tmp/ltrgame-task4-balance-acc9t20x/data`, `XDG_CONFIG_HOME=/tmp/ltrgame-task4-balance-acc9t20x/config`, `XDG_CACHE_HOME=/tmp/ltrgame-task4-balance-acc9t20x/cache`. Không dùng progress thật.
- `production/qa/evidence/refactor-balance-execution-2026-11-17.json` giữ exact argv, exit, wall duration, environment, toàn bộ stdout/stderr logs, CPU và audit templates. Logs/data tạm đã xóa sau khi đóng gói evidence; không cần giữ process/app nào từ task này.
- Các JSON simulator `refactor-balance-{pilot,easy,easy_plus,normal,normal_plus,hard,hard-repeat,aborted-matrix}-2026-11-17.json` giữ engine, balance SHA-256, tick Hz, overrides `{}`, seeds/cell, Wilson CI95, thắng, finish reason, thời lượng và telemetry combat. Artifact aborted là partial, không phải kết quả run thành công.

## Lệnh và giới hạn thực thi

Tất cả lệnh chạy với ba XDG ở trên và `cwd` là root. Python `subprocess.run` thu log và enforce timeout; đây là các lệnh Godot thực tế (không dùng `--set`):

```sh
G=/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64
P=/home/konits/projects/ltrgame/buffalo-fighting
"$G" --headless --path "$P" --script res://tests/balance_sim_smoke_test.gd
"$G" --headless --path "$P" --script res://tools/balance_sim.gd -- --matches=4 --seed=20261117 --level=L01 --pair=NORMAL,HARD --swap-sides --output=res://production/qa/evidence/refactor-balance-pilot-2026-11-17.json
# Đã thử, nhưng TIMEOUT: không dùng làm mẫu chính
"$G" --headless --path "$P" --script res://tools/balance_sim.gd -- --matches=4 --seed=20261117 --swap-sides --output=res://production/qa/evidence/refactor-balance-matrix-2026-11-17.json
# 5 lệnh thành công; exact expanded argv có trong execution JSON
for profile in EASY EASY_PLUS NORMAL NORMAL_PLUS HARD; do
  label=$(printf '%s' "$profile" | tr '[:upper:]' '[:lower:]')
  "$G" --headless --path "$P" --script res://tools/balance_sim.gd -- --matches=4 --seed=20261117 --pair=NORMAL,"$profile" --swap-sides --output=res://production/qa/evidence/refactor-balance-${label}-2026-11-17.json
done
"$G" --headless --path "$P" --script res://tools/balance_sim.gd -- --matches=4 --seed=20261117 --pair=NORMAL,HARD --swap-sides --output=res://production/qa/evidence/refactor-balance-hard-repeat-2026-11-17.json
```

| Run | Exit / limit | Wall s | Simulator elapsed s |
|---|---|---:|---:|
| smoke | 0 / 180s | 1.368 | n/a |
| pilot L01 NORMAL/HARD | 0 / 180s | 1.669 | 0.545 |
| unfiltered matrix, **partial** | killed SIGKILL (-9), wrapper 1 / 180s | 180 (timeout threshold) | 178.455 last completed row |
| NORMAL/EASY | 0 / 60s | 8.190 | 5.947 |
| NORMAL/EASY_PLUS | 0 / 60s | 6.387 | 5.236 |
| NORMAL/NORMAL | 0 / 60s | 12.857 | 11.744 |
| NORMAL/NORMAL_PLUS | 0 / 60s | 7.691 | 6.547 |
| NORMAL/HARD | 0 / 60s | 6.586 | 5.375 |
| HARD repeat | 0 / 60s | 6.085 | 4.934 |

Smoke reports `deterministic=true complete=true combat=true metrics=true` (four short matches with its own 12s in-memory duration, not used as normal balance evidence). Successful profile runs and smoke still emit shutdown diagnostics `4 ObjectDB instances were leaked at exit` / `1 resources still in use at exit`; exit 0 is **not** a clean-log claim. No fix/investigation undertaken.

### Bounded-run correction

The initial unfiltered CLI includes **10 profiles**, including five DRILL profiles, thus 500 cells × 4 = 2,000 intended trials rather than the desired five progression profiles. It hit the explicit 180s cap after 177 saved cells (708 completed trials), last saved L02 HARD/EASY_PLUS; incomplete in-flight work is unknown. `subprocess.run(timeout=180)` killed/waited for its child; the Python wrapper exited 1 before appending metadata, which was recorded explicitly afterward; partial JSON was renamed `refactor-balance-aborted-matrix-2026-11-17.json`. This overbroad attempt is disclosed, excluded from balance conclusions, and not retried. Scope was narrowed using the existing `--pair` filter to five progression profiles across all five levels, 100 completed main trials; no simulator changes.

## Reproducibility, seeds, result distribution

Simulator sorts all ten profile names before applying selection. Its seed row offset therefore includes skipped DRILL rows: `first_seed = 20261117 + row_index * 4`; each cell uses `first_seed..first_seed+3`. Trials 0–1 have NORMAL in physical slot1; trials 2–3 swap it to slot2, with normalized `wins` still ordered NORMAL/opponent. Each swapped trial uses a **different seed**, not a matched same-seed crossover; per-slot AI RNG is `seed*2+side`, so this is not a proof of absence of side bias. Pilot L01 HARD shares the same four seeds/results as the main HARD row and is not independent evidence.

| Opponent | First seeds L01 / L02 / L03 / L04 / L05 | NORMAL wins by level (/4) | Pooled NORMAL/opponent | Physical slot1/slot2 wins | Mean simulated seconds |
|---|---|---|---|---|---:|
| EASY | 20261457 / 20261857 / 20262257 / 20262657 / 20263057 | 4 / 4 / 4 / 4 / 4 | 20/0 | 10/10 | 39.01 |
| EASY_PLUS | 20261461 / 20261861 / 20262261 / 20262661 / 20263061 | 4 / 2 / 1 / 3 / 4 | 14/6 | 10/10 | 21.73 |
| NORMAL | 20261469 / 20261869 / 20262269 / 20262669 / 20263069 | 3 / 2 / 2 / 2 / 1 | 10/10 | 12/8 | 54.60 |
| NORMAL_PLUS | 20261473 / 20261873 / 20262273 / 20262673 / 20263073 | 2 / 1 / 3 / 1 / 3 | 10/10 | 8/12 | 30.76 |
| HARD | 20261465 / 20261865 / 20262265 / 20262665 / 20263065 | 0 / 0 / 0 / 0 / 0 | 0/20 | 10/10 | 23.56 |

Main sample: **FLEE 100, TIME 0, LOT 0**, physical wins 50/50. Mean seconds in table are controller tick seconds, not wall time; JSON additionally holds per-cell median/p90. P90 at n=4 is the maximum, not a reliable tail estimate. All five HARD rows repeated identically across **every JSON field except elapsed_s**, using unchanged seeds/balance, exit 0; that confirms this narrow repeat, not all possible simulator state reuse sequences.

### Interpretation and recommendation

- HARD defeated NORMAL and NORMAL defeated EASY in this sample; near-neighbor outcomes vary. There is no evidence here that NORMAL_PLUS is reliably harder than NORMAL for humans, nor that EASY_PLUS/L03 is too hard: four seeds/cell and AI policies are not player ability.
- Per-cell Wilson 95% intervals are wide (4/4 approximately 0.510–1.000; 0/4 approximately 0–0.490). Pooling across distinct level/seed distributions does not establish progression causality.
- Reusing NORMAL across five profiles is a bounded baseline, **not all-pairs coverage**, not a season completion test. No human input, perception of tells/camera, tutorial comprehension, controller latency, skill progression, ceremony/outro pacing, audio or LAN measured. TIME/LOT absent here remain uncovered by this sample.
- Simulator uses actual arena/controller, real AI `build_input` and `simulate_tick`, but disables automatic processing/presentation, removes visuals/VFX/replay, skips already-decided outro, and manually advances ticks. It does not exercise the extracted UI or packaged startup. Reuse/reset and telemetry are limited to the existing smoke contract.
- **Recommended balance changes: none justified.** Preserve current config. If main wants further evidence, predefine a hypothesis (e.g. adjacent difficulty ordering), use paired seeds/side treatment deliberately, include real-human novices/experienced players and target performance measurements, then decide whether a larger sample is warranted. No numeric tuning inferred from this small run.

## Export/README/credits audit

### Preset and templates

- One preset `Windows Desktop`, x86_64, executable `build/windows/buffalo-fighting.exe`, embedded PCK. `export_filter=all_resources`; exclude filter covers `tests/*, tools/*, addons/godot_mcp/*, production/*, design/*`. No custom templates configured. No Linux preset present; host is Linux and requested output is Windows, so a future export alone will not prove target execution.
- Read-only checks: absolute Godot `--version`; `ls -ld /home/konits/.local/share/godot{,/export_templates}`; search `/home/konits/.local/share`, `/home/konits/projects/Godot`, `/home/konits/.config/godot` (maxdepth 5) for export template directories, `windows_debug_x86_64.exe`, `windows_release_x86_64.exe`, `*.tpz`; check adjacent `_sc_`/`editor_data`. Standard export_templates directory exists but is **empty**, no matching binaries/archives/custom templates found; no self-contained editor_data. Current `XDG_DATA_HOME` unset outside isolated runs.
- Exact blocker: expected installed template path `/home/konits/.local/share/godot/export_templates/4.7.2.stable/windows_debug_x86_64.exe` (README debug command) does not exist; release equivalent absent too. Isolated XDG has no templates either. **Export deliberately not attempted**, as directed; no build output created and no install/download performed. Main must obtain user authorization/provision compatible templates, then export to an approved path and run on Windows target hardware.
- README correctly calls out Standard Godot and 4.7.2 export templates, gives the Windows debug command and warns LAN needs two machines. Its earlier generic “Godot 4.7” and “ba profile AI” wording does not describe five concrete progression profiles shown by `levels.json`; this is documentation precision debt, not edited here.
- Export contents have not been inspected because no PCK exists. Need verify actual exclusion recursion, data/resources included, and no dev/server/source/QA artifacts leaked. `.gdignore` does not replace inspection of an exported package.

### Credits and provenance

- `docs/ASSET_CREDITS.csv` records sources/licenses for Quaternius villager, Kenney nature/VFX/impact assets, Poly Haven mud/sand and procedural sound provenance; several project-created buffalo/icon rows explicitly retain unknown/unverified rights. These are recorded claims, **not independent legal clearance**.
- CSV identifies old `assets/characters/buffalo/buffalo.glb` as current, but `scenes/buffalo.tscn:4` loads `assets/characters/buffalo_hero/buffalo_hero.glb`, consistent with README/AGENTS. CSV has **no HERO/ancient_east, bamboo fence or sparse_grass entries**; README mentions those runtime/source assets. Need owner provenance/license review and accurate current-asset inventory before redistribution; no rights assumptions or credit edits made.
- Credits CSV lives under `docs/` (documented as `.gdignore`), so do not assume it ships or is accessible to players. Supply an approved distributable credits/license bundle and check the actual package. Reference images have unresolved source/license fields even when excluded from runtime; source-repo distribution is a separate question.

## Demo acceptance checklist — pending, not claimed

1. [ ] Main resolves R1 with actual live dual-window/two-machine LAN evidence; pause consent/resume/settings, result, rematch and disconnect, without calling staged screenshots live behavior.
2. [ ] Provision compatible templates with approval; record export exact command, exit/log, engine/template version, artifact SHA-256/size and package inventory. No debug-server/dev assets or user data; include required licenses/credits.
3. [ ] Run packaged executable on clean **Windows target hardware** without editor/source tree. Record OS/CPU/GPU/driver/RAM/resolution and average/p95/p99 frame time or 1% low under combat/VFX/crowd; 720p and 1080p input/focus/resize/window/fullscreen. Headless timings here cannot substitute.
4. [ ] Rehearse demo: fresh isolated data → menu → ceremony → Solo tutorial/movement/horn/dash/guard/parry → live CLASH hook/release → pause/settings/return → real match result/retry → five-round season and card awards → training/free play → LAN on two machines → result/rematch/disconnect → quit/relaunch with safe persistence. Reserve time for actual matches; staged result screens are not wins.
5. [ ] External human sessions: novices and experienced players, consented notes, seeds/level/profile, completion/retry/time, stamina/SPIRIT understanding, tell readability, camera/mouse capture, training comprehension, fatigue/accessibility and perceived fairness. Document observations separately from AI outcomes; no invented testers/quotes.
6. [ ] Verify invalid/unreadable progress never overwrites real saves; use disposable paths for demo preparation. Decide whether persistence may be reset only with explicit owner consent.
7. [ ] Main reviews full acceptance matrix, outstanding shutdown diagnostics, asset provenance and R1; owns release decision. This bounded report neither reruns the full suite nor upgrades the prior Task3 acceptance to overall acceptance.

## Cleanup and remaining work

All child runs are synchronous and reaped; timeout child was killed/waited by Python, no background jobs/servers/worker terminals created. Raw owned logs were embedded into execution JSON before deleting only `/tmp/ltrgame-task4-balance-acc9t20x`. Remaining blockers: real human playtest, R1, target-machine performance/input, export templates and independent packaged execution, accurate/cleared current asset credits. No active app was required to be preserved by this task.
