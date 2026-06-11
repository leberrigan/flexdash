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

        <!-- ── D-Link DUB-H7: centered badge + wide hub body + port boxes below ── -->
        <template v-if="hub.type === 'dlink'">
          <!-- Centered Pi-port badge above the hub -->
          <rect :x="(SVG_W - 72) / 2" y="6" width="72" height="24" rx="6" fill="#111827"/>
          <text :x="SVG_W / 2" y="22" text-anchor="middle"
                font-size="14" font-weight="bold" fill="white" font-family="sans-serif">
            P{{ hub.piLogicalPort }}
          </text>
          <!-- Wide hub body -->
          <g transform="translate(17, 35)">
            <rect x="0" y="0" width="440" height="65" rx="8" fill="#252525"/>
            <rect x="1" y="1" width="438" height="34" rx="7" fill="#303030"/>
            <text x="220" y="22" text-anchor="middle"
                  fill="#555" font-size="11" font-weight="bold"
                  font-family="sans-serif" letter-spacing="0.5">D-Link  DUB-H7</text>
            <!-- 7 USB-A port openings, evenly spaced -->
            <g v-for="pi in 7" :key="pi" :transform="`translate(${4 + (pi-1)*60}, 36)`">
              <rect x="0" y="0" width="55" height="26" rx="2" fill="#111"/>
              <rect x="2" y="2" width="51" height="17" rx="1" fill="#090909"/>
              <rect x="11" y="5" width="29" height="5" fill="#262626"/>
            </g>
            <!-- Power LED -->
            <circle cx="433" cy="59" r="4" fill="#22C55E" opacity="0.85"/>
            <circle cx="433" cy="59" r="6" fill="#22C55E" opacity="0.15"/>
          </g>
          <!-- Port boxes centred below the hub -->
          <g :transform="`translate(${(SVG_W - hub.ports.length * (BOX_W + BOX_GAP) + BOX_GAP) / 2}, 106)`">
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
          <!-- Input node (Pi port) -->
          <rect x="12" y="22" width="58" height="32" rx="6" fill="#111827"/>
          <text x="41" y="42" text-anchor="middle"
                font-size="14" font-weight="bold" fill="white" font-family="sans-serif">
            p{{ hub.piLogicalPort }}
          </text>
          <!-- Bezier curves + port boxes, vertically spread -->
          <g v-for="(hp, hi) in hub.ports" :key="hp.logicalPort">
            <path :d="splitterCurve(hi)" stroke="#4B5563" stroke-width="2.5" fill="none"/>
            <g :transform="`translate(370, ${18 + hi * 69})`">
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

        <!-- ── Generic multi-port hub ── -->
        <template v-else>
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
const HUB_H = 155   // vertical space per hub section (sized for D-Link layout)
const BOX_W = 44    // hub port box width
const BOX_H = 44    // hub port box height
const BOX_GAP = 5   // gap between hub port boxes

// Pixel positions of port label overlays within each 475×194 board image.
// RPi 3 and 4 have separate images — Ethernet is on opposite sides.
// Calibrate x/y in browser dev tools; w/h are fixed at 60×55.
const PORT_POS = {
  '3': {   // RPi 3B / 3B+: calibrated against rpi3-usb-ports.png
    1: { x: 218, y:   0, w: 60, h: 55 },
    2: { x: 218, y: 105, w: 60, h: 55 },
    3: { x: 367, y:   0, w: 60, h: 55 },
    4: { x: 367, y: 105, w: 60, h: 55 },
  },
  '4': {   // RPi 4B: x/y TBC — calibrate with rpi4-usb-ports.png
    1: { x: 218, y:   0, w: 60, h: 55 },
    2: { x: 218, y: 105, w: 60, h: 55 },
    3: { x: 367, y:   0, w: 60, h: 55 },
    4: { x: 367, y: 105, w: 60, h: 55 },
  },
  '5': {   // RPi 5: x/y TBC — calibrate with rpi5-usb-ports.png
    1: { x: 155, y:   0, w: 60, h: 55 },
    2: { x: 155, y: 105, w: 60, h: 55 },
    3: { x: 310, y:   0, w: 60, h: 55 },
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

// Width (px) of each hub illustration — used to position generic hub port boxes
const ILLUST_W = {
  generic: 115,   // 95px body + 20px margin
}

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
      hubEntries.push({ path: m[1], logPort: m[2], depth: parts.length,
                        piPath: parts[0] + '.' + parts[1] })
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
    title:    { type: String, default: 'USB Port Map' },
    devices:  { type: Object, default: () => ({}),
                tip: 'devices dict keyed by logical port number — bind to `devices`' },
    portmap:  { type: String, default: '',
                tip: 'portmap file text — bind to `portmap_file`' },
    model_image: { type: String, default: '/rpi4-usb-ports.png',
                   tip: 'board USB port image URL — bind to `portmap/refimage`' },
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
      const hubs = []
      for (const [piPath, connected] of Object.entries(byPiPath)) {
        const maxDepth = Math.max(...connected.map(d => d.depth))
        const type = maxDepth >= 4        ? 'dlink'
                   : connected.length <= 2 ? 'splitter'
                   :                         'generic'
        const activeEntries = hubEntries.filter(e => e.piPath === piPath && e.depth === maxDepth)
        const portMap = new Map()
        for (const e of activeEntries) portMap.set(e.logPort, { logicalPort: e.logPort })
        for (const c of connected)     portMap.set(c.logPort, { logicalPort: c.logPort })
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
    isHubPort(portNum) {
      return this.sortedHubs.some(h => String(h.piLogicalPort) === String(portNum))
    },

    portFill(portNum) {
      if (this.isHubPort(portNum)) return '#111827'
      const dev = this.devices[String(portNum)]
      if (!dev) return '#374151'
      const freq = parseFloat(dev.frequency)
      if (!isNaN(freq) && freq > 0) {
        if (freq > 430 && freq < 436) return '#7C3AED'
        if (freq > 140 && freq < 200) return '#0D9488'
        return '#6B7280'
      }
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

    portLabel2(portNum) {
      if (this.isHubPort(portNum)) return 'HUB'
      const dev = this.devices[String(portNum)]
      return dev ? this.typeCode(dev.type) : ''
    },

    typeCode(type) {
      if (!type) return '???'
      const base = type.split('/')[0]
      return TYPE_CODES[base] || TYPE_CODES[type] || type.slice(0, 3).toUpperCase()
    },

    hubIllustW(type) {
      return ILLUST_W[type] || ILLUST_W.generic
    },

    // Cubic bezier from input badge to a vertically-arranged port box.
    // portIdx 0 = upper box, 1 = lower; box tops at 18 + portIdx*69.
    splitterCurve(portIdx) {
      const sx = 70, sy = 38
      const ex = 370
      const ey = 18 + portIdx * 69 + BOX_H / 2
      const cx1 = sx + (ex - sx) * 0.4
      const cx2 = ex - (ex - sx) * 0.3
      return `M ${sx} ${sy} C ${cx1} ${sy} ${cx2} ${ey} ${ex} ${ey}`
    },
  },
}
</script>
