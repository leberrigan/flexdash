<!-- USB Port Map — shows RPi USB ports and connected radio devices colour-coded by frequency.
     Hub topology (multi-port hubs, Y-splitters) is drawn below the board image.
     Copyright ©2024 sensorgnome contributors, MIT license
-->
<template>
  <div class="usb-map d-flex flex-column" style="overflow-x:auto">
    <svg :width="SVG_W" :height="svgH" :viewBox="`0 0 ${SVG_W} ${svgH}`"
         xmlns="http://www.w3.org/2000/svg" style="display:block">

      <!-- RPi reference image embedded at its natural 475×194 size -->
      <image v-if="imageUrl" :href="imageUrl" x="0" y="0" :width="SVG_W" height="194"/>
      <rect v-else x="0" y="0" :width="SVG_W" height="194" fill="#1F2937" rx="4"/>

      <!-- Coloured port label — always visible; two lines: port number + type code -->
      <g v-for="(pos, portNum) in portPositions" :key="`p${portNum}`">
        <rect
          :x="pos.x" :y="pos.y" :width="pos.w" :height="pos.h" rx="4"
          :fill="portFill(portNum)"
          fill-opacity="0.88"
        />
        <!-- Red stroke ring on error -->
        <rect v-if="isErr(portNum)"
          :x="pos.x" :y="pos.y" :width="pos.w" :height="pos.h" rx="4"
          fill="none" stroke="#EF4444" stroke-width="2.5"
        />
        <!-- Port number (large, upper line) -->
        <text
          :x="pos.x + pos.w / 2" :y="pos.y + pos.h * 0.37"
          text-anchor="middle" dominant-baseline="middle"
          font-size="17" font-weight="bold"
          fill="white" font-family="sans-serif">
          {{ portNum }}
        </text>
        <!-- Device type code (smaller, lower line) — blank when nothing connected -->
        <text
          :x="pos.x + pos.w / 2" :y="pos.y + pos.h * 0.72"
          text-anchor="middle" dominant-baseline="middle"
          font-size="10" font-weight="bold"
          fill="rgba(255,255,255,0.85)" font-family="'Courier New', Courier, monospace">
          {{ portLabel2(portNum) }}
        </text>
      </g>

      <!-- Hub sections — one per hub group, stacked below the Pi image -->
      <g v-for="(hub, idx) in sortedHubs" :key="`h${hub.piPath}`"
         :transform="`translate(0, ${PI_H + idx * HUB_H})`">

        <line x1="0" y1="1" :x2="SVG_W" y2="1" stroke="#374151" stroke-width="1"/>

        <!-- ── D-Link DUB-H7 illustration (7-port hub, depth-4 portmap paths) ── -->
        <template v-if="hub.type === 'dlink'">
          <!-- Section badge -->
          <rect x="8" y="4" width="36" height="16" rx="3" fill="#111827"/>
          <text x="26" y="16" text-anchor="middle"
                font-size="11" font-weight="bold" fill="white" font-family="sans-serif">
            p{{ hub.piLogicalPort }}
          </text>
          <g transform="translate(10, 24)">
            <!-- Body -->
            <rect x="0" y="0" width="175" height="62" rx="6" fill="#252525"/>
            <!-- Top face -->
            <rect x="1" y="1" width="173" height="32" rx="5" fill="#303030"/>
            <!-- Label -->
            <text x="87" y="20" text-anchor="middle"
                  fill="#666" font-size="9" font-weight="bold"
                  font-family="sans-serif" letter-spacing="0.3">D-Link  DUB-H7</text>
            <!-- 7 USB-A female port openings -->
            <g v-for="pi in 7" :key="pi" :transform="`translate(${4 + (pi-1)*23}, 35)`">
              <rect x="0" y="0" width="18" height="22" rx="2" fill="#111"/>
              <rect x="2" y="2" width="14" height="15" rx="1" fill="#090909"/>
              <rect x="5" y="5" width="8" height="4" fill="#262626"/>
            </g>
            <!-- Power LED -->
            <circle cx="170" cy="57" r="3" fill="#22C55E" opacity="0.85"/>
            <circle cx="170" cy="57" r="5" fill="#22C55E" opacity="0.15"/>
          </g>
          <!-- Hub port boxes to the right of illustration -->
          <g :transform="`translate(${hubIllustW(hub.type) + 18}, 20)`">
            <g v-for="(hp, hi) in hub.ports" :key="hp.logicalPort"
               :transform="`translate(${hi * (BOX_W + BOX_GAP)}, 0)`">
              <rect x="0" y="0" :width="BOX_W" :height="BOX_H" rx="4"
                    :fill="portFill(hp.logicalPort)"
                    :fill-opacity="devices[hp.logicalPort] ? 0.90 : 0.22"/>
              <rect v-if="isErr(hp.logicalPort)"
                    x="0" y="0" :width="BOX_W" :height="BOX_H" rx="4"
                    fill="none" stroke="#EF4444" stroke-width="2"/>
              <text :x="BOX_W/2" y="14" text-anchor="middle"
                    font-size="9" fill="rgba(255,255,255,0.6)" font-family="sans-serif">
                p{{ hp.logicalPort }}
              </text>
              <text :x="BOX_W/2" y="32" text-anchor="middle"
                    font-size="11" font-weight="bold"
                    fill="white" font-family="'Courier New', Courier, monospace">
                {{ devices[hp.logicalPort] ? typeCode(devices[hp.logicalPort].type) : '' }}
              </text>
            </g>
          </g>
        </template>

        <!-- ── USB Y-splitter: schematic diagram ── -->
        <template v-else-if="hub.type === 'splitter'">
          <!-- Input node (Pi port badge, larger than D-Link section badge) -->
          <rect x="12" y="22" width="58" height="32" rx="6" fill="#111827"/>
          <text x="41" y="42" text-anchor="middle"
                font-size="14" font-weight="bold" fill="white" font-family="sans-serif">
            p{{ hub.piLogicalPort }}
          </text>
          <!-- Bezier curves + port boxes, one per hub port, arranged vertically -->
          <g v-for="(hp, hi) in hub.ports" :key="hp.logicalPort">
            <path :d="splitterCurve(hi)" stroke="#4B5563" stroke-width="2.5" fill="none"/>
            <!-- Port box, stacked vertically on the right -->
            <g :transform="`translate(370, ${8 + hi * 56})`">
              <rect x="0" y="0" :width="BOX_W" :height="BOX_H" rx="4"
                    :fill="portFill(hp.logicalPort)"
                    :fill-opacity="devices[hp.logicalPort] ? 0.90 : 0.22"/>
              <rect v-if="isErr(hp.logicalPort)"
                    x="0" y="0" :width="BOX_W" :height="BOX_H" rx="4"
                    fill="none" stroke="#EF4444" stroke-width="2"/>
              <text :x="BOX_W/2" y="14" text-anchor="middle"
                    font-size="9" fill="rgba(255,255,255,0.6)" font-family="sans-serif">
                p{{ hp.logicalPort }}
              </text>
              <text :x="BOX_W/2" y="32" text-anchor="middle"
                    font-size="11" font-weight="bold"
                    fill="white" font-family="'Courier New', Courier, monospace">
                {{ devices[hp.logicalPort] ? typeCode(devices[hp.logicalPort].type) : '' }}
              </text>
            </g>
          </g>
        </template>

        <!-- ── Generic multi-port hub illustration ── -->
        <template v-else>
          <!-- Section badge -->
          <rect x="8" y="4" width="36" height="16" rx="3" fill="#111827"/>
          <text x="26" y="16" text-anchor="middle"
                font-size="11" font-weight="bold" fill="white" font-family="sans-serif">
            p{{ hub.piLogicalPort }}
          </text>
          <g transform="translate(10, 24)">
            <rect x="0" y="0" width="95" height="52" rx="4" fill="#252525"/>
            <rect x="1" y="1" width="93" height="26" rx="3" fill="#303030"/>
            <text x="47" y="17" text-anchor="middle"
                  fill="#666" font-size="9" font-family="sans-serif">USB Hub</text>
            <g v-for="pi in 4" :key="pi" :transform="`translate(${4 + (pi-1)*22}, 29)`">
              <rect x="0" y="0" width="17" height="18" rx="2" fill="#111"/>
              <rect x="2" y="2" width="13" height="11" rx="1" fill="#090909"/>
              <rect x="5" y="4" width="7" height="3" fill="#222"/>
            </g>
            <circle cx="90" cy="48" r="2.5" fill="#22C55E" opacity="0.8"/>
          </g>
          <!-- Hub port boxes to the right of illustration -->
          <g :transform="`translate(${hubIllustW(hub.type) + 18}, 20)`">
            <g v-for="(hp, hi) in hub.ports" :key="hp.logicalPort"
               :transform="`translate(${hi * (BOX_W + BOX_GAP)}, 0)`">
              <rect x="0" y="0" :width="BOX_W" :height="BOX_H" rx="4"
                    :fill="portFill(hp.logicalPort)"
                    :fill-opacity="devices[hp.logicalPort] ? 0.90 : 0.22"/>
              <rect v-if="isErr(hp.logicalPort)"
                    x="0" y="0" :width="BOX_W" :height="BOX_H" rx="4"
                    fill="none" stroke="#EF4444" stroke-width="2"/>
              <text :x="BOX_W/2" y="14" text-anchor="middle"
                    font-size="9" fill="rgba(255,255,255,0.6)" font-family="sans-serif">
                p{{ hp.logicalPort }}
              </text>
              <text :x="BOX_W/2" y="32" text-anchor="middle"
                    font-size="11" font-weight="bold"
                    fill="white" font-family="'Courier New', Courier, monospace">
                {{ devices[hp.logicalPort] ? typeCode(devices[hp.logicalPort].type) : '' }}
              </text>
            </g>
          </g>
        </template>

      </g><!-- end hub sections -->
    </svg>

    <!-- Colour legend -->
    <div class="d-flex flex-wrap gap-3 px-2 pt-1 pb-1"
         style="font-size:11px; opacity:0.7">
      <span v-for="item in legend" :key="item.label" class="d-flex align-center" style="gap:4px">
        <svg width="12" height="12" style="flex-shrink:0">
          <rect width="12" height="12" rx="2" :fill="item.color"/>
        </svg>
        {{ item.label }}
      </span>
    </div>
  </div>
</template>

<style scoped>
.usb-map { width: 100%; }
</style>

<script>
const SVG_W = 475
const PI_H  = 194
const HUB_H = 110   // vertical space per hub section
const BOX_W = 44    // hub port box width
const BOX_H = 44    // hub port box height
const BOX_GAP = 5   // gap between hub port boxes

// Pixel positions of port label overlays within each 475×194 board image.
// RPi 3 and 4 use separate image files (rpi3-usb-ports.png / rpi4-usb-ports.png)
// because their Ethernet ports are on opposite sides and the layouts differ.
// Calibrate x/y values in browser dev tools; w/h are fixed at 60×55.
const PORT_POS = {
  '3': {   // RPi 3B / 3B+: x/y TBC once rpi3-usb-ports.png is available
    1: { x: 155, y:  52, w: 60, h: 55 },
    2: { x: 155, y: 135, w: 60, h: 55 },
    3: { x: 340, y:  52, w: 60, h: 55 },
    4: { x: 340, y: 135, w: 60, h: 55 },
  },
  '4': {   // RPi 4B: ethernet far-left in image; USB groups at ~x=220 and ~x=375
    1: { x: 220, y:  52, w: 60, h: 55 },
    2: { x: 220, y: 135, w: 60, h: 55 },
    3: { x: 375, y:  52, w: 60, h: 55 },
    4: { x: 375, y: 135, w: 60, h: 55 },
  },
  '5': {   // RPi 5: x/y TBC once rpi5-usb-ports.png is available
    1: { x: 155, y:  52, w: 60, h: 55 },
    2: { x: 155, y: 135, w: 60, h: 55 },
    3: { x: 310, y:  52, w: 60, h: 55 },
    4: { x: 310, y: 135, w: 60, h: 55 },
  },
}

// 2–3-letter abbreviations for known device types
const TYPE_CODES = {
  'rtlsdr':          'RTL',
  'funcubePro':      'FCD',
  'funcubeProPlus':  'FCD',
  'airspy':          'AM',
  'airspyhf':        'AHF',
  'CTT/CornellRcvr': 'CTT',
  'DigiBabel':       'DBU',
  'NanoBabel':       'NB',
  'usbAudio':        'AUD',
}

// Width (px) of each hub illustration, used to position port boxes to its right
const ILLUST_W = {
  dlink:   195,   // 175px body + 20px margin
  generic: 115,   // 95px body + 20px margin
  // splitter: not used — splitter draws its own port boxes vertically
}

// Parse portmap_file text.
// Returns { piPorts: { "1.X": logPort }, hubEntries: [{ path, logPort, depth, piPath }] }
// Hub entries are kept flat — grouping and type classification happens in sortedHubs
// using the *connected* devices, not just the portmap, to avoid misclassification when
// the portmap lists multiple alternative hub configurations (generic + D-Link) for the
// same Pi port.
function parsePortmap(text) {
  const piPorts    = {}
  const hubEntries = []

  for (const raw of (text || '').split('\n')) {
    const m = raw.replace(/#.*/, '').trim().match(/^([\d.]+)\s*->\s*(\d+)$/)
    if (!m) continue
    const parts = m[1].split('.')
    if (parts.length === 2) {
      piPorts[m[1]] = m[2]
    } else if (parts.length >= 3) {
      hubEntries.push({
        path:    m[1],
        logPort: m[2],
        depth:   parts.length,
        piPath:  parts[0] + '.' + parts[1],
      })
    }
  }

  return { piPorts, hubEntries }
}

export default {
  name: 'UsbPortMap',

  help: `Show RPi USB port layout with connected devices colour-coded by signal type.

Bind \`devices\` to the \`devices\` topic, \`portmap\` to \`portmap_file\`,
and \`model_image\` to \`portmap/refimage\`.

Colours: purple = FSK (433/434 MHz Lotek digital), teal = PPM (VHF Lotek analog),
grey = other device, black = USB hub.
Hub sections drawn automatically from portmap topology.`,

  props: {
    title: {
      type: String, default: 'USB Port Map',
    },
    devices: {
      type: Object, default: () => ({}),
      tip: 'devices dict keyed by logical port number — bind to `devices`',
    },
    portmap: {
      type: String, default: '',
      tip: 'portmap file text — bind to `portmap_file`',
    },
    model_image: {
      type: String, default: '/rpi4-usb-ports.png',
      tip: 'board USB port image URL — bind to `portmap/refimage`',
    },
  },

  data() {
    return {
      SVG_W, PI_H, HUB_H, BOX_W, BOX_H, BOX_GAP,
      legend: [
        { color: '#7C3AED', label: 'FSK'          },
        { color: '#0D9488', label: 'PPM'          },
        { color: '#6B7280', label: 'Other device' },
        { color: '#111827', label: 'USB hub'      },
      ],
    }
  },

  computed: {
    piModel() {
      return (this.model_image || '').match(/rpi(\d+)-usb-ports/)?.[1] || '4'
    },
    imageUrl() {
      return this.model_image || null
    },
    portPositions() {
      return PORT_POS[this.piModel] || PORT_POS['4']
    },
    topology() {
      return parsePortmap(this.portmap)
    },
    sortedHubs() {
      const { piPorts, hubEntries } = this.topology

      // Step 1: group connected devices by Pi-level path prefix (first two path segments).
      // Only devices whose port_path has depth ≥ 3 are behind a hub.
      const byPiPath = {}
      for (const [logPort, dev] of Object.entries(this.devices || {})) {
        const pp = dev.port_path || ''
        if (!pp || pp === '--') continue
        const parts = pp.split('.')
        if (parts.length < 3) continue
        const piPath = parts[0] + '.' + parts[1]
        if (!byPiPath[piPath]) byPiPath[piPath] = []
        byPiPath[piPath].push({ logPort, dev, depth: parts.length })
      }

      if (Object.keys(byPiPath).length === 0) return []

      // Step 2: for each Pi port with hub devices, build a hub section.
      const hubs = []
      for (const [piPath, connected] of Object.entries(byPiPath)) {
        // Hub type determined by deepest connected device path:
        //   depth 4 (e.g. 1.5.4.1) → D-Link (internal chip adds an extra hop)
        //   depth 3 (e.g. 1.5.1)   → generic hub or Y-splitter
        const maxDepth = Math.max(...connected.map(d => d.depth))
        const type = maxDepth >= 4        ? 'dlink'
                   : connected.length <= 2 ? 'splitter'
                   :                         'generic'

        // Step 3: select only portmap entries matching the active depth to avoid
        // duplicates when portmap lists both generic (depth-3) and D-Link (depth-4)
        // entries for the same Pi port.
        const activeEntries = hubEntries.filter(
          e => e.piPath === piPath && e.depth === maxDepth
        )

        // Step 4: merge portmap entries with connected devices, deduped by logPort.
        const portMap = new Map()
        for (const e of activeEntries) portMap.set(e.logPort, { logicalPort: e.logPort })
        for (const c of connected)     portMap.set(c.logPort, { logicalPort: c.logPort })

        // Sort 1-9 ascending; 0 (D-Link's 10th port alias) sorts last
        const ports = [...portMap.values()].sort((a, b) => {
          const an = a.logicalPort === '0' ? 100 : Number(a.logicalPort)
          const bn = b.logicalPort === '0' ? 100 : Number(b.logicalPort)
          return an - bn
        })

        hubs.push({ piPath, piLogicalPort: piPorts[piPath] || '?', type, ports })
      }

      return hubs.sort((a, b) => (Number(a.piLogicalPort) || 0) - (Number(b.piLogicalPort) || 0))
    },
    svgH() {
      return PI_H + this.sortedHubs.length * HUB_H
    },
  },

  methods: {
    // True when the Pi port has a hub plugged in (not a direct device)
    isHubPort(portNum) {
      return this.sortedHubs.some(h => String(h.piLogicalPort) === String(portNum))
    },

    portFill(portNum) {
      if (this.isHubPort(portNum)) return '#111827'  // black for hub ports

      const dev = this.devices[String(portNum)]
      if (!dev) return '#374151'  // dark grey for empty ports

      const freq = parseFloat(dev.frequency)
      if (!isNaN(freq) && freq > 0) {
        if (freq > 430 && freq < 436) return '#7C3AED'  // FSK UHF
        if (freq > 140 && freq < 200) return '#0D9488'  // PPM VHF
        return '#6B7280'
      }

      // Type-based fallback when frequency not yet reported
      const t = dev.type || ''
      if (t.startsWith('rtlsdr') || t.startsWith('airspy') || t === 'funcubeProPlus')
        return '#7C3AED'
      if (t === 'funcubePro' || t === 'usbAudio')
        return '#0D9488'
      return '#6B7280'
    },

    isErr(portNum) {
      return this.devices[String(portNum)]?.state === 'error'
    },

    // Second line of the Pi port label: type code, 'HUB', or blank
    portLabel2(portNum) {
      if (this.isHubPort(portNum)) return 'HUB'
      const dev = this.devices[String(portNum)]
      return dev ? this.typeCode(dev.type) : ''
    },

    typeCode(type) {
      if (!type) return '???'
      // Strip trailing tuner info appended by rtlsdr/airspy handlers (e.g. "rtlsdr/R820T2")
      const base = type.split('/')[0]
      return TYPE_CODES[base] || TYPE_CODES[type] || type.slice(0, 3).toUpperCase()
    },

    hubIllustW(type) {
      return ILLUST_W[type] || ILLUST_W.generic
    },

    // Cubic bezier path from the splitter input badge to a port box.
    // portIdx 0 = upper box, 1 = lower box (for a standard 2-port splitter).
    splitterCurve(portIdx) {
      const sx = 70, sy = 38                    // right edge / mid of input badge
      const ex = 370                             // left edge of port box column
      const ey = 8 + portIdx * 56 + BOX_H / 2  // centre of this port's box
      const cx1 = sx + (ex - sx) * 0.4
      const cx2 = ex - (ex - sx) * 0.3
      return `M ${sx} ${sy} C ${cx1} ${sy} ${cx2} ${ey} ${ex} ${ey}`
    },
  },
}
</script>
