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

        <!-- Black Pi-port badge showing which Pi port this hub is on -->
        <rect x="8" y="4" width="36" height="16" rx="3" fill="#111827"/>
        <text x="26" y="16" text-anchor="middle"
              font-size="11" font-weight="bold" fill="white" font-family="sans-serif">
          p{{ hub.piLogicalPort }}
        </text>

        <!-- ── D-Link DUB-H7 illustration (7-port hub, depth-4 portmap paths) ── -->
        <g v-if="hub.type === 'dlink'" transform="translate(10, 24)">
          <!-- Body -->
          <rect x="0" y="0" width="175" height="62" rx="6" fill="#252525"/>
          <!-- Top face (slightly lighter) -->
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

        <!-- ── USB Y-splitter illustration (1 male → 2 female) ── -->
        <g v-else-if="hub.type === 'splitter'" transform="translate(10, 22)">
          <!-- USB-A male connector body -->
          <rect x="29" y="0" width="28" height="17" rx="2" fill="#1A1A1A"/>
          <!-- Connector opening / cavity -->
          <rect x="32" y="3" width="22" height="11" rx="1" fill="#363636"/>
          <!-- Gold contact strips -->
          <rect x="35" y="5" width="16" height="2.5" fill="#C09000" opacity="0.9"/>
          <rect x="35" y="9" width="16" height="2.5" fill="#C09000" opacity="0.9"/>
          <!-- Cable strain-relief sleeve -->
          <rect x="39" y="17" width="8" height="3" rx="1" fill="#111"/>
          <!-- Braided cable stem -->
          <rect x="40" y="20" width="6" height="14" rx="2" fill="#1A1A1A"/>
          <line x1="40" y1="22" x2="46" y2="25" stroke="#2A2A2A" stroke-width="1.2"/>
          <line x1="40" y1="25" x2="46" y2="28" stroke="#2A2A2A" stroke-width="1.2"/>
          <line x1="40" y1="28" x2="46" y2="31" stroke="#2A2A2A" stroke-width="1.2"/>
          <!-- Splitter junction -->
          <ellipse cx="43" cy="36" rx="6" ry="5" fill="#111"/>
          <!-- Left arm cable -->
          <path d="M43 41 L17 57" stroke="#1A1A1A" stroke-width="7" stroke-linecap="round"/>
          <!-- Right arm cable -->
          <path d="M43 41 L69 57" stroke="#1A1A1A" stroke-width="7" stroke-linecap="round"/>
          <!-- Cable braiding on arms -->
          <path d="M38 43 L14 57" stroke="#2A2A2A" stroke-width="1.2"/>
          <path d="M48 43 L72 57" stroke="#2A2A2A" stroke-width="1.2"/>
          <!-- Left female USB-A port -->
          <rect x="7" y="57" width="20" height="14" rx="2" fill="#1A1A1A"/>
          <rect x="9" y="60" width="16" height="8" rx="1" fill="#090909"/>
          <rect x="12" y="62" width="10" height="3" fill="#222"/>
          <!-- Right female USB-A port -->
          <rect x="59" y="57" width="20" height="14" rx="2" fill="#1A1A1A"/>
          <rect x="61" y="60" width="16" height="8" rx="1" fill="#090909"/>
          <rect x="64" y="62" width="10" height="3" fill="#222"/>
        </g>

        <!-- ── Generic multi-port hub illustration ── -->
        <g v-else transform="translate(10, 24)">
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

        <!-- Hub port boxes (one per logical port mapped in portmap) -->
        <g :transform="`translate(${hubIllustW(hub.type) + 18}, 20)`">
          <g v-for="(hp, hi) in hub.ports" :key="hp.logicalPort"
             :transform="`translate(${hi * (BOX_W + BOX_GAP)}, 0)`">
            <!-- Port box background -->
            <rect x="0" y="0" :width="BOX_W" :height="BOX_H" rx="4"
                  :fill="portFill(hp.logicalPort)"
                  :fill-opacity="devices[hp.logicalPort] ? 0.90 : 0.22"/>
            <!-- Error stroke -->
            <rect v-if="isErr(hp.logicalPort)"
                  x="0" y="0" :width="BOX_W" :height="BOX_H" rx="4"
                  fill="none" stroke="#EF4444" stroke-width="2"/>
            <!-- Logical port number (small, top) -->
            <text :x="BOX_W/2" y="14" text-anchor="middle"
                  font-size="9" fill="rgba(255,255,255,0.6)" font-family="sans-serif">
              p{{ hp.logicalPort }}
            </text>
            <!-- Device type code (bold, centre) -->
            <text :x="BOX_W/2" y="32" text-anchor="middle"
                  font-size="11" font-weight="bold"
                  fill="white" font-family="'Courier New', Courier, monospace">
              {{ devices[hp.logicalPort] ? typeCode(devices[hp.logicalPort].type) : '' }}
            </text>
          </g>
        </g>

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

// Pixel positions of port label overlays within each 475×194 PNG.
// Key '34' is the shared RPi 3B/4B image (rpi34-usb-ports.png).
// Key '5' is the RPi 5 image (rpi5-usb-ports.png).
// Calibrate x/y in browser dev tools; w/h fixed at 60×55.
const PORT_POS = {
  '34': {  // RPi 3B / 3B+ / 4B shared image
    1: { x: 220, y:  68, w: 60, h: 55 },
    2: { x: 220, y: 135, w: 60, h: 55 },
    3: { x: 375, y:  68, w: 60, h: 55 },
    4: { x: 375, y: 135, w: 60, h: 55 },
  },
  '5': {   // RPi 5
    1: { x: 155, y:  30, w: 60, h: 55 },
    2: { x: 155, y: 105, w: 60, h: 55 },
    3: { x: 310, y:  30, w: 60, h: 55 },
    4: { x: 310, y: 105, w: 60, h: 55 },
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

// Width (px) of each hub illustration, used to position the port boxes to its right
const ILLUST_W = {
  dlink:    195,   // 175px body + 20px margin
  splitter: 100,   // ~86px body + 14px margin
  generic:  115,   // 95px body + 20px margin
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
      type: String, default: '/rpi34-usb-ports.png',
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
      return (this.model_image || '').match(/rpi(\d+)-usb-ports/)?.[1] || '34'
    },
    imageUrl() {
      return this.model_image || null
    },
    portPositions() {
      return PORT_POS[this.piModel] || PORT_POS['34']
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
    // Returns true when the Pi port has a hub plugged in (not a direct device)
    isHubPort(portNum) {
      return this.sortedHubs.some(h => String(h.piLogicalPort) === String(portNum))
    },

    portFill(portNum) {
      // Pi port with a hub → black
      if (this.isHubPort(portNum)) return '#111827'

      const dev = this.devices[String(portNum)]
      if (!dev) return '#374151'  // empty

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
  },
}
</script>
