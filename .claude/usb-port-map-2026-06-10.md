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

## Status
- [x] Widget file created: `src/widgets/usb-port-map.vue`
- [ ] Port label positions calibrated in browser
- [ ] Add to a FlexDash tab in `fd-config.json`
- [ ] Test with real device data
- [ ] Optional: fix frequency data in dashboard.js genDevInfo()
