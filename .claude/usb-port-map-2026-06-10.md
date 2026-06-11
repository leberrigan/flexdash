# USB Port Map widget — 2026-06-10

## Goal
A new FlexDash widget that visually maps RPi USB ports and connected radio devices.
- SVG-based, scalable
- RPi port-numbering PNG embedded at natural 475×194 size
- Coloured overlays on each port label box (purple = FSK 433/434 MHz, teal = other)
- Hub sections drawn below the Pi image: D-Link DUB-H7, Y-splitter, or generic hub
- Topology derived from `portmap_file` topic (already published)

## File created
`src/widgets/usb-port-map.vue`

## Props (bind in FlexDash config)
| Prop | Topic | Notes |
|------|-------|-------|
| `devices` | `devices` | dict keyed by logical port number; each has `{port, port_path, type, state, frequency}` |
| `portmap` | `portmap_file` | portmap text; parsed to build hub topology |
| `model_image` | `portmap/refimage` | URL like `/rpi4-port-numbering.png`; selects port label positions |

## Color scheme
- `#7C3AED` purple: FSK 433/434 MHz (RTL-SDR, Airspy, FC+)
- `#0D9488` teal: other frequencies (FCD, VHF, etc.)
- `#6B7280` grey: unknown frequency (type-based fallback used)
- Red stroke: device in error state

## Hub type detection (from portmap parsing)
- `ports.length <= 2`: Y-splitter
- `maxDepth >= 4`: D-Link DUB-H7 (internal chip adds an extra path level)
- Otherwise: generic 4-port hub

## SVG illustrations (inline in widget template)
- **D-Link DUB-H7**: dark charcoal rounded body, 7 USB-A port openings in a row, green power LED
- **Y-splitter**: USB-A male at top, braided cable splits to 2 USB-A female connectors
- **Generic hub**: simplified dark block with 4 port openings

## Pending calibration
Port label positions in `PORT_POS` are approximate (estimated from visual inspection).
Need to calibrate by opening browser dev tools and checking actual SVG overlay positions.
RPi models: 3, 4, 5.

## Known limitation: frequency data
`devices/{port}/frequency` is initialised to `Acquisition.lotek_freq` for ALL VAH/GRH devices
in `handle_devAdded` (dashboard.js:417). This is wrong for RTL-SDR/Airspy which tune to 434 MHz,
not the Lotek VHF frequency. Widget falls back to type-based colour inference when frequency
doesn't match the 430–436 MHz UHF band. Proper fix: look up actual tuning frequency from
acquisition plan in `genDevInfo()`.

## Hub detection fix (2026-06-10)
**Bug**: portmap lists both depth-3 (generic hub) AND depth-4 (D-Link) entries for the same
Pi port. Old code combined them → maxDepth=4 → D-Link regardless of what's actually connected.
Also caused duplicate p7 (both `1.5.4 → 7` at depth-3 and `1.5.4.1 → 7` at depth-4).

**Fix**: `parsePortmap` now returns flat `hubEntries` (no pre-grouping). `sortedHubs` computed:
1. Scans `devices` for hub-connected devices (port_path depth ≥ 3)
2. Groups by Pi-level path prefix
3. Determines type from **connected device** path depths (not portmap depths)
4. Filters portmap entries to the matching depth only → no duplicates
5. Hub section only shown when devices are actually connected to that hub

**Hub type ambiguity** (Y-splitter vs generic hub with ≤2 devices):
Cannot be distinguished from `devices` data alone. Current heuristic: `connected.length <= 2`
at depth-3 → splitter illustration. Long-term fix: server-side USB hub enumeration
(scan `/sys/bus/usb/devices/` for hub vendor/product IDs; D-Link DUB-H7 = Genesys Logic
GL850G, VID 05e3). Add to sensorgnome-control as a new topic `usb_hubs`.

## Round 2 UI changes (2026-06-11)
- Switched to `rpi34-usb-ports.png` / `rpi5-usb-ports.png` (no printed port numbers on image)
- Port overlays: always visible 60×55px boxes; two-line (port number large + type code)
- Port fill: dark grey when empty, black when hub connected, colour when device present
- Hub sections: "↳ Hub on port X" text replaced with black "pN" badge
- TYPE_CODES: airspy→'AM', NanoBabel→'NB', DigiBabel→'DBU', funcubeProPlus→'FCD'
- Legend: FSK (purple) / PPM (teal) / Other device (grey) / USB hub (black)
- `dashboard.js portmapRefImage()`: RPi 3+4 → `/rpi34-usb-ports.png`, RPi 5 → `/rpi5-usb-ports.png`
- PORT_POS: dropped old '3'/'4' keys (now use shared '34' key); '5' key kept
  - x/y estimates based on user's example (port 2 at x=220, y=135); need browser calibration

## Status
- [x] Widget file created: `src/widgets/usb-port-map.vue`
- [x] Hub type detection fixed — uses connected device depths, not portmap depths
- [x] Duplicate port bug fixed
- [x] Round 2 UI changes applied (2026-06-11)
- [x] dashboard.js portmapRefImage() updated
- [ ] Add `rpi34-usb-ports.png` (and `rpi5-usb-ports.png`) to `sensorgnome-control/src/public/`
- [ ] Port label positions calibrated in browser (PORT_POS['34'] x/y are estimates)
- [ ] Add to a FlexDash tab in `fd-config.json`
- [ ] Test with real device data
- [ ] Optional: server-side USB hub enumeration (vendor/product ID detection)
- [ ] Optional: fix frequency data in dashboard.js genDevInfo()
