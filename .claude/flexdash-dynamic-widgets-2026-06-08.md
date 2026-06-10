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
