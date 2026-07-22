# Incremental SketchyBar Modernization Design

Date: 2026-07-22
Status: Ready to implement

---

## Hard Constraints

These are non-negotiable. Implementation must not touch them.

**1. Stay on sketchybar 2.23.0 -- no binary upgrade, no SbarLua rebuild.**
The installed SbarLua `.so` was compiled against 2.23.0. An upgrade risks a Lua 5.4->5.5 module
ABI mismatch that silently breaks the bar. Any reference to a newer API surface is out of scope.

**2. Preserve the glass theme.**
Do not alter these values or re-add pill borders:
- Bar background: `0x282c2e34` (colors.lua:14), blur_radius 40 (settings.lua:43)
- Item pill bg: `bg1 = 0x50363944`, `bg2 = 0x50414550` (colors.lua:22-23)
- default.lua sets `border_width = 0` on item backgrounds (default.lua:49) -- keep it zero

**3. Preserve the aerospace event contract exactly.**
The fixes made to `spaces_aerospace.lua` must survive the refactor intact:
- Custom events subscribed: `wm_workspace_change`, `wm_focus_change`, `space_windows_change`,
  `aerospace_monitor_change`, `spaces_refresh`, `display_change`
- `spaces_refresher` hidden item (spaces_aerospace.lua:239) and `space_window_observer`
  (spaces_aerospace.lua:256) must continue to exist with identical subscriptions
- `env.FOCUSED_WORKSPACE` comparison (spaces_aerospace.lua:172) is the highlight mechanism -- do not change it
- The `space_windows_change` event is triggered by move-node-to-workspace bindings in
  `.config/aerospace/aerospace.toml` -- do not rename it
- workspace-name-to-index click handler uses `split(env.NAME, ".")` (spaces_aerospace.lua:183) -- keep item naming scheme

**4. No io.popen or os.execute in callbacks.**
Use `sbar.exec` for all async CLI calls. Synchronous io.popen is acceptable only at module
init time (before the event loop), matching current usage in `wait_for_aerospace` and
`build_ws_monitor_map`.

---

## Context: What Already Exists

A few "plan items" are partially or fully done. The spec calls them out so implementation
skips duplicate work.

- **scroll_texts**: already set to `true` in `default.lua:71` and in
  `helpers/display_settings.lua:226` (apply_defaults_per_display). front_app inherits it
  globally. Goal 2 for front_app reduces to adding `max_chars` / fixed width so the scroll
  has a bounded trigger, not enabling scroll_texts from scratch.

- **media artwork**: `media.lua` already sets `background.image.string = "media.artwork"` on
  `media_cover` (media.lua:14-17) and already uses `sbar.delay(5, animate_detail)`
  (media.lua:142). The "use artwork as background.image" and "sbar.delay auto-collapse" goals
  described for group 3 are already implemented. What remains for media is the popup controls
  polish (they exist but use synchronous `click_script`; optionally convert to `sbar.exec`
  callbacks) and verifying the interrupt counter logic is correct.

- **volume slider**: `volume.lua` already has `sbar.add("slider", ...)` (volume.lua:61-81),
  a `mouse.scrolled` handler (volume.lua:175-178), and `SwitchAudioSource` device listing.
  Goal 3 for volume is to add modifier-key-aware scroll (10% step when shift/option held)
  and verify the slider is wired to `volume_change` correctly (it is, via volume.lua:107).

- **bracket pills**: cpu, memory, battery, and wifi all already have `sbar.add("bracket", ...)`
  with `background = { color = colors.bg1 }`. Group 4 is cosmetic polish only, not a
  structural bracket addition.

- **helpers/aerospace.lua does NOT exist yet.** The `helpers/` directory contains only
  `app_icons.lua`, `default_font.lua`, and `display_settings.lua`. Creating
  `helpers/aerospace.lua` is the core deliverable of group 1.

---

## Goals by Item Group

### Group 1 -- spaces/aerospace helper extraction (do first, highest value)

**Goal:** Factor all `aerospace` CLI knowledge out of `spaces_aerospace.lua` into a new
`helpers/aerospace.lua` module. Rendering logic and event subscriptions in
`spaces_aerospace.lua` stay behaviorally identical; only the CLI layer moves.

**New file: `.config/sketchybar/helpers/aerospace.lua`**

Expose these functions (modeled on falleco/dotfiles pattern):

```
aerospace.get_workspaces()             -- returns list of workspace names (all monitors)
aerospace.get_focused()                -- returns focused workspace name string
aerospace.is_workspace_selected(ws, focused_ws)  -- pure comparison, multi-monitor aware
aerospace.get_windows(ws, callback)    -- sbar.exec wrapper, calls callback(apps_json_table)
aerospace.get_monitors()               -- returns monitor count as number
aerospace.get_workspaces_for_monitor(m) -- returns workspace list for monitor index m
aerospace.wait_for_aerospace(callback) -- async retry loop; calls callback(true/false)
```

All functions that call the CLI use `sbar.exec`. The two synchronous callers that run at
module load time (`wait_for_aerospace` + `build_ws_monitor_map`) may stay synchronous for
now since they run before the event loop; document this exception in the module header.

`spaces_aerospace.lua` is updated to `require("helpers.aerospace")` and call these
functions in place of its inline `popen_lines` + hardcoded command strings. The 4 command
constants at the top of the file (`WORKSPACE_LIST_CMD`, `FOCUSED_CMD`, and the two inline
string constructions) all move into the helper.

Explicit non-goal: do not change which events fire, how highlight is computed, or the
`items_by_ws` / `padding_by_ws` tables. The module-level `workspaces`, `current_workspace`,
and pcall-protected build block in spaces_aerospace.lua keep their structure.

**Files touched by group 1:**
- NEW `.config/sketchybar/helpers/aerospace.lua`
- EDIT `.config/sketchybar/items/spaces_aerospace.lua`

---

### Group 2 -- front_app + calendar

**front_app (`items/front_app.lua`)**

`scroll_texts` is already on globally. Add:
- `label.max_chars = 20` (or equivalent pixel width) so the scroll triggers on long names
  rather than truncating silently
- `label.width = "dynamic"` to avoid the item collapsing when the app name is short

Current `front_app.lua` has no background color set; optionally add `background.color =
colors.bg1` to give it the same pill appearance as the right-side widgets, keeping
`border_width = 0`.

No change to `swap_menus_and_spaces` click behavior.

**calendar (`items/calendar.lua`)**

Minor polish only:
- The `border_width` on the background at calendar.lua:36 is set to
  `math.max(1, math.floor(1 * scale))` which puts a 1px border on the pill -- set it to 0
  to match the borderless glass style from the hard constraint above
- Keep `os.date("%a. %b. %d")` icon and `os.date("%I:%M %p")` label format unchanged
- Keep `update_freq = 30`, click behavior unchanged

**Files touched by group 2:**
- EDIT `.config/sketchybar/items/front_app.lua`
- EDIT `.config/sketchybar/items/calendar.lua`

---

### Group 3 -- media + volume

**media (`items/media.lua`)**

The core design (artwork as background.image, sbar.delay auto-collapse, interrupt counter,
popup controls) is already implemented. Work items:

1. Convert popup control `click_script` strings (media.lua:78, 84, 90) to inline
   `mouse.clicked` subscriptions using `sbar.exec("nowplaying-cli ...")` for consistency
   with the no-io.popen-in-callbacks rule
2. Guard the whitelist check: if `nowplaying-cli` is not installed, the `media_change`
   callback should degrade gracefully (check `env.INFO` for nil before indexing)
3. The `media_artist.label.max_chars = 18` and `media_title.label.max_chars = 16`
   (media.lua:47, 66) already truncate; leave them as-is since scroll_texts is global

**volume (`items/widgets/volume.lua`)**

Already has slider and scroll. Add:
- Modifier-aware scroll: when `env.MODIFIER` is `"shift"` or `"option"`, step by 10%;
  otherwise step by 1%. Replace the delta passthrough in `volume_scroll` (volume.lua:175-178)
  with:
  ```lua
  local function volume_scroll(env)
      local step = (env.MODIFIER == "shift" or env.MODIFIER == "option") and 10 or 1
      local dir = (tonumber(env.SCROLL_DELTA) or 0) > 0 and step or -step
      sbar.exec('osascript -e "set volume output volume ' ..
          '(output volume of (get volume settings) + ' .. dir .. ')"')
  end
  ```
- Guard `SwitchAudioSource` calls (volume.lua:141-168): if the binary is absent, skip
  device enumeration rather than crashing. Use `sbar.exec("which SwitchAudioSource", ...)` check.

**Files touched by group 3:**
- EDIT `.config/sketchybar/items/media.lua`
- EDIT `.config/sketchybar/items/widgets/volume.lua`

---

### Group 4 -- cpu / memory / wifi / battery (cosmetic polish)

All four widgets already have bracket pills (`widgets.cpu.bracket`, `widgets.memory.bracket`,
`widgets.battery.bracket`, `widgets.wifi.bracket`) with `background.color = colors.bg1`.
This group is low-risk tidying only.

**cpu (`items/widgets/cpu.lua`) + memory (`items/widgets/memory.lua`)**

Both already call `cpu:push({load/100.})` / `memory:push({used/100.})`. No idiom change
needed. Tidy:
- Ensure `graph.color` update in the callback uses the same color thresholds on both --
  they are slightly inconsistent (cpu uses 30/60/80; memory uses 50/70/85). Align to the
  memory thresholds as they are more meaningful for RAM pressure.
- Add `background.border_width = 0` on the graph item background to suppress any inherited
  border from `default.lua`'s image border rule

**wifi (`items/widgets/wifi.lua`)**

The `wifi_bracket` `border_width` at wifi.lua:73 is `math.max(1, math.floor(1 * scale))` --
set to 0 to match borderless glass. The popup items are already detailed and functional;
no structural changes.

**battery (`items/widgets/battery.lua`)**

The `widgets.battery.bracket` at battery.lua:109 has no `border_width` set (inherits 0 from
default). Confirm and leave. No other changes needed.

**Files touched by group 4:**
- EDIT `.config/sketchybar/items/widgets/cpu.lua`
- EDIT `.config/sketchybar/items/widgets/memory.lua`
- EDIT `.config/sketchybar/items/widgets/wifi.lua`
- EDIT `.config/sketchybar/items/widgets/battery.lua` (confirm-only, likely no change)

---

## Cross-Cutting Patterns

**Brackets:** All right-side widget clusters already use brackets with `bg1`. New pill
groupings should follow the same `sbar.add("bracket", name, {item.name, ...}, { background =
{ color = colors.bg1, border_width = 0 } })` pattern.

**Animation:** `sbar.animate("tanh", N, fn)` is already used in spaces_aerospace.lua (N=10
for label update, N=30 for spaces_indicator expand/collapse). New animations, if any, use
the same tanh easing with N<=30. Avoid animation on high-frequency event callbacks
(cpu_update fires every 2s, network_update every 2s) -- do not add animation there.

**External CLIs and graceful degradation:**

| CLI | Used by | Required behavior if absent |
|-----|---------|----------------------------|
| `nowplaying-cli` | media.lua | media_change events won't fire; guard env.INFO nil check |
| `SwitchAudioSource` | volume.lua | skip device list popup; show slider only |
| `osascript` | volume.lua (volume set) | core volume read still works via volume_change event |
| `aerospace` | spaces_aerospace.lua | existing wait_for_aerospace returns false; zero items drawn, bar still loads |
| `pmset` | battery.lua | sbar.exec callback gets empty string; icon/label default to "!" / "?" |
| `networksetup`, `ipconfig` | wifi.lua | popup fields show placeholder strings |

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Regressing aerospace event wiring (workspace switch, highlight, pill click, window-move refresh) | Group 1 keeps event contract letter-for-letter identical. After implementation, manually verify: switch workspace -> pill highlights, click pill -> focus changes, move window -> icons refresh, multi-monitor display routing unchanged |
| SbarLua module version mismatch from an incidental binary upgrade | Pin sketchybar at 2.23.0 in nix-darwin; do not run `brew upgrade sketchybar` during this work |
| Animation overuse degrading perf | Use tanh only, N<=30, never in 2s/4s polling callbacks |
| media.lua: interrupt counter going negative | The existing logic decrements before checking; add `interrupt = math.max(0, interrupt - 1)` guard |
| io.popen in display_settings.lua:5 (sketchybar --query displays) | This runs at init time before the event loop; acceptable, not a callback violation |

---

## Implementation Plan and Sequencing

All four groups are implemented in one pass. User reviews the full result live after a
single `sketchybar --reload`. Commits are one per group, unpushed.

### Commit 1 -- helpers/aerospace.lua + spaces_aerospace.lua refactor
Files: `helpers/aerospace.lua` (new), `items/spaces_aerospace.lua` (edit)
Key change: inline popen_lines calls replaced with helpers; event subscriptions untouched.
Verify after reload: workspace pills display correctly, switch/click/move all work.

### Commit 2 -- front_app + calendar polish
Files: `items/front_app.lua`, `items/calendar.lua`
Key change: front_app gets max_chars + width; calendar border_width -> 0.

### Commit 3 -- media popup cleanup + volume modifier scroll
Files: `items/media.lua`, `items/widgets/volume.lua`
Key change: media click_scripts -> sbar.exec; volume modifier-aware 1%/10% step.

### Commit 4 -- widget tidy (cpu/memory/wifi/battery)
Files: `items/widgets/cpu.lua`, `items/widgets/memory.lua`, `items/widgets/wifi.lua`,
`items/widgets/battery.lua` (confirm-only)
Key change: align color thresholds, zero pill border_widths.

---

## Verification Checklist

After `sketchybar --reload`:

- [ ] `sketchybar --reload` exits 0
- [ ] `pgrep -x sketchybar` returns a PID (bar running)
- [ ] No errors in `~/.local/share/sketchybar/sketchybar.log` (or `/tmp/sketchybar.log`)
- [ ] Workspace pills render on correct monitors
- [ ] Switching workspace highlights the correct pill and de-highlights others
- [ ] Clicking a pill focuses the workspace
- [ ] Moving a window to another workspace refreshes app icons on both source and dest pills
- [ ] front_app scrolls when the app name exceeds ~20 chars (test with "IntelliJ IDEA Ultimate")
- [ ] Calendar shows no pill border
- [ ] Media shows album art thumbnail when Spotify/Music is playing
- [ ] Media text expands on hover, collapses after 5s of no hover
- [ ] Volume slider appears on click; dragging sets volume
- [ ] Volume scroll on the icon changes volume 1% per tick; shift+scroll changes 10% per tick
- [ ] CPU and memory graphs continue updating with correct color thresholds
- [ ] Wifi popup shows SSID, IP, subnet, router on click
