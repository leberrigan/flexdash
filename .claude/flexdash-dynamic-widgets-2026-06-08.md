# FlexDash: Dynamic widgets + show/hide — 2026-06-08

## Goal
Two new features to add to the leberrigan/flexdash fork:
1. **Dynamic widget array** — a widget that renders child widgets driven by a server data variable
2. **Show/hide** — hide a widget based on a server data variable, or via a toggle button

---

## Architecture notes (from code read)

- Config lives in `$config.widgets` (keyed by ID). Each widget: `{kind, id, rows, cols, static:{}, dynamic:{}}`.
- `widget-wrap.vue` resolves `dynamic` bindings against `store.sd`, passes resolved values to child via `v-bind`.
- `std-grid.vue` renders widget IDs from `grid.widgets[]` using `<component :is="editComponent[w]">`.
- `panel.vue` does the same within a panel widget.
- `store.sd` is the live server data namespace; all dynamic bindings watch paths inside it.

---

## Feature 1: Dynamic widget array

### Approach options

**Option A — New container widget (`dynamic-panel.vue`)**
- Widget has one prop: `widgets` (type: Array) bound to a store.sd variable.
- Each element: `{ kind: "Stat", title: "foo", value: 42, ... }` (flat prop map).
- Widget renders `<component :is="item.kind" v-bind="item">` for each element, bypassing widget-wrap / config system.
- Pros: simple, no config mutation; server drives everything at runtime.
- Cons: no dynamic bindings per child (each child's props are literal values from the array, not reactive store.sd watchers); edit mode can't configure individual children.

**Option B — Config-driven dynamic widgets**
- Server sends config mutations to add/remove widgets from a grid (using existing `$config/widgets/…` topic protocol).
- Grid re-renders when config changes (already reactive).
- Pros: full widget feature parity; edit mode works.
- Cons: complex; requires server to manage config IDs; could corrupt saved config.

**Recommendation: Option A** for sensorgnome's use case (device driving its own status UI).
The "widgets" array arriving from the server is a snapshot, not wired to store.sd paths.
If reactive child props are needed later, add a `dynamic` sub-key per item.

### Files to add/modify
- **New file**: `src/widgets/dynamic-panel.vue`
- `src/prelude.js` — register the new widget in the palette

---

## Feature 2: Show/hide widget

### Approach options

**Option A — `visible` meta-prop in widget-wrap**
- Add `visible` as a recognized prop in `widget-wrap.vue`.
- If a `visible` dynamic binding is set and resolves to falsy, hide the card (`v-show`).
- Already flows naturally through `genBindings()` — just needs a check in the template.
- Pros: works for any existing widget without changes; configurable per-widget via prop-edit.
- Cons: hidden widget still occupies grid space (CSS `visibility`/`v-show` keeps layout).

**Option A+** — use `v-if` instead of `v-show` to remove from DOM and grid flow.
Problem: the grid uses CSS grid-auto-flow which would just reflow around missing items.
So `v-show` may be preferable to avoid layout jumps.

**Option B — toggle button in widget-wrap chrome**
- Add a show/hide icon button (like the existing full-page expand button) to widget-wrap.
- State stored locally (data property) or sent to server via output binding.
- Independent of server data unless explicitly bound.

**Option C — both**: visibility driven by server var (Option A), plus a toggle button that sends to an output binding (Option B) so the server can control it programmatically.

**Recommendation: Option A** first (data-driven visibility via `visible` binding on widget-wrap).
Widget remains in layout when hidden (`v-show`), which is consistent with normal grid behavior.
Toggle button can be added later.

### Files to modify
- `src/components/widget-wrap.vue` — add `visible` binding check + `v-show`/`v-if`

---

## Feature 3: Auth dialog fix (connections.vue + auth-unknown.vue)
- `connections.vue`:
  - Removed `defineAsyncComponent(name, loader)` (wrong 2-arg call; components already registered globally)
  - Removed unused `defineAsyncComponent` import
  - Fixed `auth-unknown` exclusion check in `auth_strategies` loop (`name !== 'auth-unknown'`)
  - Replaced `<v-dialog eager :value="show_auth">` (empty, V2 syntax) with:
    `<v-dialog :model-value="!!show_auth" @update:modelValue="...">` containing
    `<component :is="show_auth" :config="auth_config" @change="authDone">`
- `auth-unknown.vue`:
  - Replaced `v-simple-table` (V2, removed) with `v-table density="compact"` (V3)
  - Removed `<template v-slot:default>` slot wrapper around tbody

## Auth bug fixes (2026-06-10 session 2)

Three bugs causing auth to fail or show wrong UI:

1. **`flexdash.html` wrong bundle filenames**: Referenced `index.15f7c1ef.js` and
   `index.b6dd8f1f.css` which don't exist. Correct files: `index.f7268a74.js` +
   `index.02099a86.css`. The page loaded but the app never mounted.

2. **`connections.vue` doAuth opened connections dialog**: `doAuth` was calling
   `this.show_dialog = true` which opens the full server-settings dialog ON TOP of the
   auth widget. User saw the big settings page ("the page you had created") instead of
   just the auth dialog. Fixed by removing `this.show_dialog = true` from `doAuth`.

3. **`connections.vue` authDone double-start**: `authDone` explicitly called
   `c.conn.start(config)` AND setting `enabled = true` also triggered the
   `sockio-settings` watcher's `start()` call. Second `start()` called `stop()` on the
   first connection just as it was receiving the config, causing the config to be dropped
   ("Already got config, dropping message" guard in handleMsg). Fixed by removing the
   explicit `start()` from `authDone` — the watcher handles it.

4. **`flexdash.js` login session save race**: `login()` set `req.session.rooms = "*"` then
   immediately called `res.status(200).end()`. FlexDash received the 200 and reconnected
   the socket.io before the session file store finished writing. Server's auth check loaded
   the un-saved session → found no `rooms` → rejected again. Fixed by wrapping the response
   in `req.session.save(cb)` so the session file is committed before the 200 is sent.
   This also fixes incognito (where the file write race is more likely to lose).

## Status
- [x] Feature 1: dynamic-panel widget — `src/widgets/dynamic-panel.vue` (new)
- [x] Feature 2: collapse toggle + `visible` binding — `src/components/widget-wrap.vue` + `src/edit-panels/widget-edit.vue`

## What was implemented

### Feature 1: DynamicPanel widget
- New file: `src/widgets/dynamic-panel.vue` — auto-registered via palette-loader glob import
- Props: `widgets` (Array) — each item: `{ kind, ...staticProps, dynamic: {prop: "store/path"} }`
- `DynamicChild` sub-component (defined inline in script): sets up per-item store watchers,
  renders `<component :is="config.kind" v-bind="bindings">` via render function + `resolveComponent`
- Dynamic bindings resolved via `walkTree` on `$store.sd` (same mechanism as widget-wrap)
- No widget-wrap chrome for children — they render raw components inside DynamicPanel's card

### Feature 2: Collapse toggle + `visible` binding
- `widget-wrap.vue`:
  - `collapsed: false` added to `data()`
  - `effective_hidden` computed: `collapsed || bindings.visible === false`
  - Watch `effective_hidden` → emit `'collapse', val` to parent widget-edit
  - Template: when `collapsed`, show collapsed bar (title + chevron-down); when `!collapsed && visible!==false`,
    show normal content; when `bindings.visible===false`, show empty card
  - Collapse button (chevron-up) added to the `full-page-btn` chrome area; only shown when `!global.editMode`
  - `toggleCollapsed()` method
  - `visible` special-cased in `genBindings()` and `updateBindingValue()` so it's tracked as
    a meta-prop without being filtered out by child_props checks; excluded from `final_bindings`
- `widget-edit.vue`:
  - `collapsed: false` added to `data()`
  - `handleCollapse(val)` method sets `this.collapsed`
  - `@collapse="handleCollapse"` wired on `<widget-wrap>`
  - `widgetStyle`: when `collapsed`, returns `span 1` + `max-height: 2.5rem` to minimize grid slot

## Feature 5: collapsible meta-prop — opt-in collapse button (2026-06-10)
- Removed hardcoded chevron-up button from all widgets (was always showing in view mode).
- Added `collapsible` meta-prop (like `visible`) in `widget-wrap.vue`:
  - Special-cased in `genBindings` and `updateBindingValue` alongside `visible`
  - Collapse button (chevron-up) now has `v-if="!!bindings.collapsible"` — only shown when bound
  - Watch on `bindings.collapsible`: auto-expands the widget if collapsible goes falsy while collapsed
- Added "collapsible binding" combobox + `handleEditCollapsible` in `widget-edit.vue`
- Server sends truthy to a topic → collapse button appears on that widget; falsy → button hidden + auto-expand

## Feature 4: Visibility binding UI in widget edit panel (2026-06-10)
- **Change:** `src/edit-panels/widget-edit.vue` — added "visibility binding" combobox row below
  "output binding", using the same `sd_keys` dropdown. Sets/clears `widget.dynamic.visible`.
- **Handler:** `handleEditVisible(value)` calls `updateWidgetProp(id, 'dynamic', 'visible', value || undefined)`.
  Passing `undefined` removes the binding (treated as "not set" by genBindings).
- **How it works end-to-end:** User picks a topic in the edit panel → topic path stored in
  `widget.dynamic.visible` → widget-wrap's genBindings watches that path in store.sd →
  when server sends falsy value, widget collapses (hidden); truthy restores it.

## Bug fix: DynamicPanel routed to PanelEdit (2026-06-10)
- **Bug:** `std-grid.vue` and `panel.vue` used `kind.endsWith("Panel")` to decide whether to use
  `PanelEdit`. `DynamicPanel` matched this, getting `PanelEdit` which shows no prop editor.
- **Fix:** Added `edit_panel: true` to `src/widgets/panel.vue` export. Changed `endsWith("Panel")`
  to `palette.widgets[kind]?.edit_panel` in both `std-grid.vue` and `panel.vue`. Added `palette`
  to panel.vue's inject list. `widget-wrap.vue`'s `isPanel` uses exact `== "Panel"` already — no change.

## Feature 6: Restrict visibility/collapsible controls to specific widget types (2026-06-10)

User requested: visibility and collapsible binding UI should only appear for:
**DynamicPanel, Panel, CustomWidget, Grid, iFrame**

### Changes made:

**`widget-edit.vue`** (handles WidgetEdit — DynamicPanel, CustomWidget, IFrame):
- Added `has_visibility_controls` computed: `['DynamicPanel', 'CustomWidget', 'IFrame'].includes(this.widget.kind)`
- Added `v-if="has_visibility_controls"` to both combobox rows

**`panel-edit.vue`** (handles Panel widgets — uses PanelEdit, not WidgetEdit):
- Added `global` to inject (was missing)
- Added `sd_keys: [], collapsed: false` to data
- Modified `widgetStyle` to return an object and handle collapsed state (same as widget-edit.vue)
- Added `@collapse="handleCollapse"` on widget-wrap
- Added `v-card-text` section with visibility and collapsible comboboxes (always shown — Panel always gets them)
- Added `handleCollapse`, `handleEditVisible`, `handleEditCollapsible` methods
- Added `watch: { edit_active }` to populate `sd_keys` on edit open
- Added `dynamic: {}` initialization in `created()` for panels missing the field

**`grid-bar.vue`** (StdGrid header bar):
- Added `can_rollup: { type: Boolean, default: true }` prop
- `rollupMini` and `rollupMaxi` computed now also check `&& this.can_rollup`
- Rollup button is hidden in view mode when `can_rollup` is false (binding resolves to falsy)

**`std-grid.vue`** (StdGrid):
- Imported `walkTree` from `/src/store.js`
- Added `grid_visible: true, grid_collapsible: true, _vis_watcher: null, _coll_watcher: null` to data
- Added `sd_keys` computed: `Object.keys(this.$store.sd).sort()`
- Added watcher on `grid.dynamic` (immediate) to call `setupDynBindings`
- Added `setupDynBindings(dyn)` method: tears down old watchers, sets up new `$watch` calls
  using same path-split pattern as widget-wrap (`path.pop()` + `walkTree(sd, path)[n]`)
- Added `handleEditVisible` and `handleEditCollapsible` methods that merge into `grid.dynamic`
  and call `this.$store.updateGrid(id, { dynamic: merged })`
- Added `v-show="grid_visible"` on `<div ref="outer">` to hide entire grid
- Added `:can_rollup="grid_collapsible"` on `<grid-bar>` 
- Added visibility/collapsible comboboxes to the grid-bar slot (appear only in editMode since slot is inside `v-toolbar v-if="global.editMode"`)
- Cleanup of `_vis_watcher` and `_coll_watcher` in `beforeUnmount`

### Semantics:
- **No binding** → same as before (grid always visible, rollup always available)
- **`visible` binding** → when binding resolves to falsy, entire grid (including bar) hidden via v-show
- **`collapsible` binding** → when binding resolves to falsy, rollup button hidden; auto-expands if was rolled up

---

## Bug fix: Auth dialog — reconnect after login (2026-06-10)

**Symptom:** Auth dialog (`auth-user-password`) appeared, user could log in, but FlexDash
content never appeared afterward. Also: dialog was rendering full-width.

**Root cause:** `connections.vue`'s `authDone('success')` set `config.enabled = true` but
relied on a reactive watcher in `sockio-settings.vue` to restart the socket.io connection.
That watcher was unreliable when the connections dialog was just opened/closed during auth flow.

**Fixes:**
- `connections.vue` `authDone`: now explicitly calls `c.conn.start(config)` directly after
  setting `enabled = true`, instead of relying on the watcher. Moved `auth_conn`/`auth_config`
  reset to happen before the conditional to avoid null-ref if start() triggers another doAuth.
- `sockio.js` `start()`: added `this.stop()` at top to clean up any existing socket before
  creating a new one (idempotent — safe if called twice, e.g. direct call + watcher both fire).
- `connections.vue` auth `v-dialog`: added `max-width="440"` to prevent full-width rendering.

---

## Server usage
To bind `visible` on any widget, set in the widget config:
```json
{ "dynamic": { "visible": "some/topic" } }
```
Server sends `false` to that topic to hide the widget (empty 2.5rem card in grid).
Server sends `true` to restore it.

To use DynamicPanel, create a widget of kind `DynamicPanel`, bind `widgets` to a topic, send:
```json
[
  { "kind": "Stat", "title": "Temp", "dynamic": { "value": "sensors/temp" } },
  { "kind": "Label", "title": "OK" }
]
```
