<!-- USB Port Map — shows RPi USB ports and connected radio devices colour-coded by frequency.
     Hub topology (multi-port hubs, Y-splitters) is drawn below the board image.
     Copyright ©2024 sensorgnome contributors, MIT license
-->
<template>
  <div class="usb-map d-flex flex-column w-100">
    <svg :width="SVG_W" :height="svgH" :viewBox="`0 0 ${SVG_W} ${svgH}`"
         xmlns="http://www.w3.org/2000/svg" style="display:block" class="w-100">

      <!-- RPi reference image embedded at its natural 475×194 size -->
      <image v-if="imageUrl" :href="imageUrl" x="0" y="0" :width="SVG_W" height="194"/>
      <rect v-else x="0" y="0" :width="SVG_W" height="194" fill="#1F2937" rx="4"/>

      <!-- Port label overlays — always visible; white+border if empty, coloured if occupied -->
      <g v-for="(pos, portNum) in portPositions" :key="`p${portNum}`">
        <rect
          :x="pos.x" :y="pos.y" :width="pos.w" :height="pos.h" rx="4"
          :fill="portFill(portNum)"
          :fill-opacity="portEmpty(portNum) ? '1' : '0.88'"
          :stroke="portEmpty(portNum) ? 'black' : 'none'"
          :stroke-width="portEmpty(portNum) ? '2' : '0'"
        />
        <!-- Error ring -->
        <rect v-if="isErr(portNum)"
          :x="pos.x" :y="pos.y" :width="pos.w" :height="pos.h" rx="4"
          fill="none" stroke="#EF4444" stroke-width="2.5"
        />
        <!-- Port number -->
        <text
          :x="pos.x + pos.w / 2" :y="pos.y + pos.h * 0.37"
          text-anchor="middle" dominant-baseline="middle"
          font-size="17" font-weight="bold"
          :fill="portEmpty(portNum) ? '#111827' : 'white'"
          font-family="sans-serif">
          {{ portNum }}
        </text>
        <!-- Type code / HUB / blank -->
        <text
          :x="pos.x + pos.w / 2" :y="pos.y + pos.h * 0.72"
          text-anchor="middle" dominant-baseline="middle"
          font-size="10" font-weight="bold"
          :fill="portEmpty(portNum) ? 'rgba(0,0,0,0.6)' : 'rgba(255,255,255,0.85)'"
          font-family="'Courier New', Courier, monospace">
          {{ portLabel2(portNum) }}
        </text>
      </g>

      <!-- Hub sections — top-down bezier fan; one section per hub group -->
      <g v-for="(hub, idx) in sortedHubs" :key="`h${hub.piPath}`"
         :transform="`translate(0, ${PI_H + idx * HUB_H})`">

        <line x1="0" y1="1" :x2="SVG_W" y2="1" stroke="#374151" stroke-width="1"/>

        <!-- Input badge: same size and style as Pi port labels -->
        <rect :x="(SVG_W - BOX_W) / 2" y="5" :width="BOX_W" :height="BOX_H" rx="4" fill="#111827"/>
        <text :x="SVG_W / 2" :y="5 + BOX_H * 0.37" text-anchor="middle" dominant-baseline="middle"
              font-size="17" font-weight="bold" fill="white" font-family="sans-serif">
          {{ hub.piLogicalPort }}
        </text>
        <text :x="SVG_W / 2" :y="5 + BOX_H * 0.72" text-anchor="middle" dominant-baseline="middle"
              font-size="10" font-weight="bold" fill="rgba(255,255,255,0.85)"
              font-family="'Courier New', Courier, monospace">HUB</text>

        <!-- Bezier curves + port boxes, fanning downward -->
        <g v-for="(hp, hi) in hub.ports" :key="hp.logicalPort">
          <path :d="hubBezierPath(hi, hub.ports.length)" stroke="#4B5563" stroke-width="2" fill="none"/>
          <g :transform="`translate(${hubBoxX(hi, hub.ports.length)}, 90)`">
            <rect x="0" y="0" :width="BOX_W" :height="BOX_H" rx="4"
                  :fill="devices[hp.logicalPort] ? portFill(hp.logicalPort) : '#FFFFFF'"
                  :fill-opacity="devices[hp.logicalPort] ? '0.88' : '1'"
                  :stroke="devices[hp.logicalPort] ? 'none' : 'black'"
                  :stroke-width="devices[hp.logicalPort] ? '0' : '2'"/>
            <rect v-if="isErr(hp.logicalPort)"
                  x="0" y="0" :width="BOX_W" :height="BOX_H" rx="4"
                  fill="none" stroke="#EF4444" stroke-width="2"/>
            <!-- Port number -->
            <text :x="BOX_W / 2" :y="BOX_H * 0.37" text-anchor="middle" dominant-baseline="middle"
                  font-size="17" font-weight="bold"
                  :fill="devices[hp.logicalPort] ? 'white' : '#111827'"
                  font-family="sans-serif">
              {{ hp.logicalPort }}
            </text>
            <!-- Type code -->
            <text :x="BOX_W / 2" :y="BOX_H * 0.72" text-anchor="middle" dominant-baseline="middle"
                  font-size="10" font-weight="bold"
                  :fill="devices[hp.logicalPort] ? 'rgba(255,255,255,0.85)' : 'rgba(0,0,0,0.6)'"
                  font-family="'Courier New', Courier, monospace">
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
const SVG_W   = 475
const PI_H    = 194
const HUB_H   = 155   // height per hub section (badge 60px + curves 30px + boxes 55px + margins)
const BOX_W   = 60    // port box width — same as Pi port label overlays
const BOX_H   = 55    // port box height — same as Pi port label overlays
const BOX_GAP = 5     // gap between port boxes

// Pixel positions of port label overlays within each 475×194 board image.
// RPi 3 and 4 have separate images — their Ethernet ports are on opposite sides.
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

Colours: purple = FSK (433/434 MHz), teal = PPM (VHF), grey = other, black = hub.
Empty ports are shown as white with a black border.`,

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

    // True when a Pi port has neither a hub nor a direct device connected
    portEmpty(portNum) {
      return !this.devices[String(portNum)] && !this.isHubPort(portNum)
    },

    portFill(portNum) {
      if (this.isHubPort(portNum)) return '#111827'
      const dev = this.devices[String(portNum)]
      if (!dev) return '#FFFFFF'
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

    // X position of hub port box i (left edge) given total number of boxes
    hubBoxX(portIdx, totalPorts) {
      const totalW = totalPorts * (BOX_W + BOX_GAP) - BOX_GAP
      return Math.round((SVG_W - totalW) / 2) + portIdx * (BOX_W + BOX_GAP)
    },

    // Cubic bezier from the input badge bottom-center down to port box top-center
    hubBezierPath(portIdx, totalPorts) {
      const sx = SVG_W / 2                           // badge bottom-center x
      const sy = 5 + BOX_H                           // badge bottom y = 60
      const ex = this.hubBoxX(portIdx, totalPorts) + BOX_W / 2  // box top-center x
      const ey = 90                                  // box top y
      const cy = (sy + ey) / 2                      // control point y = 75
      return `M ${sx} ${sy} C ${sx} ${cy} ${ex} ${cy} ${ex} ${ey}`
    },
  },
}
</script>
