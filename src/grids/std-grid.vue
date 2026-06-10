<!-- StdGrid - Container to manage a grid of widgets dynamically placed on the page.
     Handles the layout of the widgets as well as the editing mode.
     Copyright ©2021 Thorsten von Eicken, MIT license, see LICENSE file
-->

<template>
  <div ref="outer" v-show="grid_visible">
    <grid-bar kind="StdGrid" :title="grid.title" :has_widgets="grid.widgets.length>0"
              v-model:rolledup="rolledup" :can_rollup="grid_collapsible"
              @changeTitle="changeTitle" @delete="$emit('delete')">
      <!-- Menu to add widget -->
      <widget-menu v-if="!global.noAddDelete" @select="addWidget" class="mr-4"></widget-menu>

      <!-- Selectors for minimum and maximum number of columns -->
      <min-max-cols :grid="grid" :max-widget="maxWidget"></min-max-cols>

      <!-- Visibility and collapsible bindings (edit mode only, inside grid-bar slot) -->
      <v-combobox label="visible" clearable density="compact" hide-details
                  style="width:18ex; flex-grow:0" class="mr-2"
                  :items="sd_keys"
                  :model-value="grid.dynamic && grid.dynamic.visible"
                  @update:modelValue="handleEditVisible($event)">
      </v-combobox>
      <v-combobox label="collapsible" clearable density="compact" hide-details
                  style="width:18ex; flex-grow:0"
                  :items="sd_keys"
                  :model-value="grid.dynamic && grid.dynamic.collapsible"
                  @update:modelValue="handleEditCollapsible($event)">
      </v-combobox>
    </grid-bar>

    <!-- Grid of widgets -->
    <div v-if="!rolledup" v-bind:style="gridScale">
      <div class="container g-grid-small pt-0 px-2 pb-2 u-tooltip-attach"
           v-bind:style="gridStyle" ref="grid">
        <component v-for="(w,ix) in widgets" :key="w" :widget_id="w" :is="editComponent[w]"
                  :ix="ix" :edit_active="ix == edit_ix" @edit="toggleEdit(ix, $event)"
                  @move="moveWidget(ix, $event)" @delete="deleteWidget(ix)"
                  @clone="cloneWidget(ix)" @teleport="(src,dst)=>teleportWidget(w, src, dst)">
        </component>
      </div>
    </div>
    <div v-if="scale != '1.00'" class="scale">grid scale {{ scale }}x</div>
  </div>
</template>

<style scoped>
/* style to make grid happen */
.g-grid-small {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(calc(v-bind(colw) * 1px), 1fr));
  grid-auto-rows: calc(v-bind(colw) * 0.66px);
  gap: calc(v-bind(gapw) * 1px);
  grid-auto-flow: dense;
}
.g-grid-margin { margin: 0.5em; }

.pasteinput {
  margin: 0 4px; padding: 0 2px; min-width: 20ex;
  color: #888;
  border: 1px solid #888; border-radius: 4px;
}

.scale { /* applied to "grid scale 1.22x" in lower right corner */
  transform-origin: top right;
  rotate: 90deg;
  position: absolute; bottom: 0px; right: 1px; z-index: 2;
  font-size: 9pt; font-weight: 700; color: #808080;
  line-height: 10pt;
}
</style>

<script scoped>

import GridBar from '/src/components/grid-bar.vue'
import { walkTree } from '/src/store.js'
import PanelEdit from '/src/edit-panels/panel-edit.vue'
import WidgetEdit from '/src/edit-panels/widget-edit.vue'
import DisabledEdit from '/src/edit-panels/disabled-edit.vue'
import WidgetMenu from '/src/menus/widget-menu.vue'
import MinMaxCols from '/src/components/min-max-cols.vue' 
import widget_ops from '/src/utils/widget-grid-ops.js'

const COLW = 120 // min width of widgets in pixels
const GAPW = 8   // gap between widgets in pixels

export default {
  name: 'StdGrid',

  components: { GridBar, PanelEdit, WidgetEdit, DisabledEdit, WidgetMenu, MinMaxCols },
  inject: [ '$store', '$config', '$conn', '$bus', 'palette', 'global' ],

  props: {
    id: { type: String }, // this grid's ID
    noEvents: { type: Boolean, default: false }, // don't send events to server, hack to embed in pop-up grid
  },

  data() { return {
    edit_ix: null,
    rolledup: false,
    pasting: false,
    gridScale: "",
    scale: 1,
    colw: COLW,
    gapw: GAPW,
    grid_visible: true,    // controlled by grid.dynamic.visible binding
    grid_collapsible: true, // controlled by grid.dynamic.collapsible binding
    _vis_watcher: null,
    _coll_watcher: null,
  }},

  computed: {
    // grid config: {id, kind, icon, widgets}
    grid() { return this.$store.gridByID(this.id) },
    widgets() { return this.grid.widgets.filter(w =>
      !w.startsWith('x') && this.$config.widgets[w]?.id == w
    )},
    minCols() { return Math.max(this.grid.min_cols || 1, this.maxWidget) },
    maxCols() { return this.grid.max_cols || 20 },
    maxWidget() { // width of widest widget (in columns)
      return Math.max(1, ...this.widgets.map(id => {
        try { return this.$store.widgetByID(id).cols }
        catch (e) { return 1 }
      }))
    },
    gridStyle() {
      // min width to fit N widgets is N*COLW, plus gaps: (N-1)*GAPW, plus l/r padding: 2*GAPW
      let min_width = this.minCols * this.colw + (this.minCols + 1) * GAPW
      let max_width = this.maxCols * this.colw + (this.maxCols + 1) * GAPW + (this.colw + GAPW - 2)
      return { minWidth: `${min_width}px`, maxWidth: `${max_width}px` }
    },

    sd_keys() { return Object.keys(this.$store.sd).sort() },

    // editComponent returns the component used to edit a widget: widget-edit or panel-edit
    editComponent() {
      return Object.fromEntries(this.widgets.map(wid => {
        if (wid.startsWith('x')) return [wid, "DisabledEdit"]
        const kind = this.$store.widgetByID(wid).kind
        if (this.palette.widgets[kind]?.edit_panel) return [wid, "PanelEdit"]
        return [wid, "WidgetEdit"]
      }))
    },
  },

  created() {
    this._ro = new ResizeObserver(() => this.scaleGrid())
  },
  mounted() {
    this._ro.observe(this.$refs.grid)
    this._ro.observe(this.$refs.outer)
    this.$bus.on(this.id, this.ctrlEvent)
  },
  beforeUnmount() {
    if(this._ro) this._ro.disconnect()
    this.$bus.off(this.id, this.ctrlEvent)
    if (this._vis_watcher) this._vis_watcher()
    if (this._coll_watcher) this._coll_watcher()
  },

  watch: {
    'grid.dynamic': {
      immediate: true,
      handler(dyn) { this.setupDynBindings(dyn) },
    },

    pasting(nv) {
      if (nv) {
        this.$refs.pasteDiv.addEventListener('paste', this.pasteWidget)
        this.$nextTick(()=>this.$refs.pasteDiv.firstChild.focus())
      } else {
        this.$refs.pasteDiv.removeEventListener('paste', this.pasteWidget)
      }
    },

    rolledup(v) {
      if (this.noEvents) return
      const payload = { type: v ? "close grid" : "open grid", cause: "manual", id: this.id }
      if (this.$conn?.serverSend) this.$conn.serverSend("dashboard", payload, "event")
    },
  },

  methods: {
    toggleEdit(ix, on) { this.edit_ix = on ? ix : null },

    ...widget_ops, // addWidget, deleteWidget, cloneWidget, moveWIdget, teleportWidget

    changeTitle(ev) { this.$store.updateGrid(this.id, { title: ev }) },

    setupDynBindings(dyn) {
      if (this._vis_watcher) { this._vis_watcher(); this._vis_watcher = null }
      if (this._coll_watcher) { this._coll_watcher(); this._coll_watcher = null }
      this.grid_visible = true
      this.grid_collapsible = true
      if (!dyn) return
      if (dyn.visible) {
        const path = dyn.visible.split('/').filter(t => t.length > 0)
        const n = path.pop()
        if (n) this._vis_watcher = this.$watch(
          () => walkTree(this.$store.sd, path)[n],
          v => { this.grid_visible = v == null || !!v },
          { immediate: true }
        )
      }
      if (dyn.collapsible) {
        const path = dyn.collapsible.split('/').filter(t => t.length > 0)
        const n = path.pop()
        if (n) this._coll_watcher = this.$watch(
          () => walkTree(this.$store.sd, path)[n],
          v => {
            this.grid_collapsible = v == null || !!v
            if (!this.grid_collapsible && this.rolledup) this.rolledup = false
          },
          { immediate: true }
        )
      }
    },

    handleEditVisible(value) {
      const dyn = { ...(this.grid.dynamic || {}) }
      if (value) dyn.visible = value; else delete dyn.visible
      this.$store.updateGrid(this.id, { dynamic: Object.keys(dyn).length ? dyn : undefined })
    },

    handleEditCollapsible(value) {
      const dyn = { ...(this.grid.dynamic || {}) }
      if (value) dyn.collapsible = value; else delete dyn.collapsible
      this.$store.updateGrid(this.id, { dynamic: Object.keys(dyn).length ? dyn : undefined })
    },

    // ctrlEvent is called via $bus in response to a ctrl message from the server
    // allows to roll-up/down the grid
    ctrlEvent(ev) {
      if (ev.action == 'open') this.rolledup = false
      if (ev.action == 'close') this.rolledup = true
    },

    scaleGrid() {
      let g = this.$refs.grid
      if (!g) return // el is removed before beforeUnmount is triggered
      let p = g.parentElement
      if (!p.clientWidth || ! g.clientWidth) {
        this.gridScale = ""
        return
      }
      
      if (true) {
        // scaling by tweaking the width of columns
        // only scale down if viewport is too narrow; 1fr in minmax already fills width upward
        let minw = this.minCols * (COLW+GAPW)
        let scaleDown = p.clientWidth / minw
        if (scaleDown < 0.75) scaleDown = 0.75
        const scale = scaleDown < 1 ? scaleDown : 1
        this.scale = scale.toFixed(2)
        this.colw = COLW * scale
      } else {
        // scaling by applying a transform to magnify the grid
        let scale = p.clientWidth / g.clientWidth
        console.log(`parentWidth=${p.clientWidth} gridWidth=${g.clientWidth} gridHeight=${g.clientHeight} scale=${scale}`)
        if (scale > 1.33) scale = 1.33
        if (scale < 0.75) scale = 0.75
        this.scale = scale.toFixed(2)
        this.gridScale = {
          'transform-origin': 'top left',
          transform: `scale(${scale})`,
          height: `${g.clientHeight*scale}px`,
        }
      }
    },

  },
}

</script>
