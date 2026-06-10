<!-- PanelEdit - Wrapper around panel components providing editing functionality.
     Copyright ©2021 Thorsten von Eicken, MIT license, see LICENSE file
-->

<template>
  <!-- without div the v-for in parent gets confused by v-menu -->
  <div class="panel-edit" :style="widgetStyle">
    
    <!-- v-overlay is used to display a floating v-card below the component for editing
         We control the activation and deactivation of the menu ourselves, though. -->
    <v-overlay :model-value="edit_active"
               location-strategy="connected" location="bottom" origin="top" offset="4" absolute
               :scrim="false" @click:outside="endEdit">
      <template #activator="{ props }">
        <!-- Panel proper inside a widget-wrap -->
        <widget-wrap :config="widget" @edit="toggleEdit" @collapse="handleCollapse"
                     :color="color" :ref="props.ref">
        </widget-wrap>
      </template>

      <!-- Editing panel shown floating below panel -->
      <v-card color="panel" class='mt-1 pb-2'>
        <!-- title and close button -->
        <title-edit what="panel" class="mt-1" :title="widget.static['title']"
                    @close="endEdit"
                    @update:title="handleTitleEdit($event)">
        </title-edit>

        <!-- Display panel help text -->
        <help-edit :text="child_help"></help-edit>

        <!-- toolbar with delete move, resize, etc -->
        <widget-edit-toolbar :widget_id="widget_id" kind="panel"
                              @delete="$emit('delete')"  @clone="$emit('clone')"
                              @move="dir=>$emit('move', dir)" @changeSolid="changeSolid"
                              @teleport="(src, dst)=>$emit('teleport', src, dst)">
        </widget-edit-toolbar>

        <!-- visibility and collapsible bindings -->
        <v-card-text>
          <v-combobox
              label="visibility binding" clearable density="compact" persistent-hint
              hint="topic that controls panel visibility (truthy=show, falsy=hide)"
              :items="sd_keys"
              :model-value="widget.dynamic && widget.dynamic.visible"
              @update:modelValue="handleEditVisible($event)">
          </v-combobox>
          <v-combobox class="mt-2"
              label="collapsible binding" clearable density="compact" persistent-hint
              hint="topic that shows/hides the collapse button (truthy=show button)"
              :items="sd_keys"
              :model-value="widget.dynamic && widget.dynamic.collapsible"
              @update:modelValue="handleEditCollapsible($event)">
          </v-combobox>
        </v-card-text>

      </v-card>
    </v-overlay>
  </div>
</template>

<style scoped>
  .panel-edit { max-width: 100%; }
</style>

<script scoped>

import WidgetWrap from '/src/components/widget-wrap.vue'
import WidgetEditToolbar from '/src/edit-panels/widget-edit-toolbar.vue'
import TitleEdit from '/src/edit-panels/title-edit.vue'
import HelpEdit from '/src/edit-panels/help-edit.vue'
import PropEdit from '/src/edit-panels/prop-edit.vue'
import md from '/src/components/md.vue'

export default {
  name: 'PanelEdit',

  components: { WidgetWrap, WidgetEditToolbar, TitleEdit, HelpEdit, PropEdit, md },
  inject: [ '$store', 'palette', 'global' ],

  props: {
    widget_id: { type: String, required: true }, // my widget ID
    edit_active: { type: Boolean, default: false }, // we're being edited
    //no_border: { type: Boolean, default: false }, // not used here...
  },

  emits: [ 'move', 'teleport', 'delete', 'clone' ],

  data() { return {
    edit_help: false,
    sd_keys: [],
    collapsed: false,
  }},

  created() {
    const p = this.$store.widgetByID(this.widget_id)
    if (!('widgets' in p.static)) {
      console.log("widget missing:", JSON.stringify(p))
      this.$store.updateWidgetProp(this.widget_id, 'static', 'widgets', [])
    }
    if (!p.dynamic) this.$store.updateWidget(this.widget_id, { dynamic: {} })
  },

  computed: {
    // handle a non-vue-standard "help" option in a widget
    child_help() {
      const p = this.palette.widgets
      if (this.widget.kind in p) return p[this.widget.kind].help
      return undefined
    },

    widgetStyle() {
      if (this.collapsed) {
        return {
          'grid-row-start': 'span 1',
          'grid-column-start': `span ${this.widget.cols||1}`,
          'max-height': '2.5rem',
          'overflow': 'hidden',
        }
      }
      return {
        'grid-row-start': `span ${this.widget.rows||1}`,
        'grid-column-start': `span ${this.widget.cols||1}`,
      }
    },

    // panel background color
    color() {
      if (this.edit_active) return 'highlight'
      return this.widget.static.solid ? '' : '#0000' },

    widget() { return this.$store.widgetByID(this.widget_id) },
  },

  watch: {
    edit_active(val) {
      if (val) this.sd_keys = Object.keys(this.$store.sd).sort()
    },
  },

  methods: {
    toggleEdit() { this.$emit('edit', !this.edit_active) },
    endEdit() { this.$emit('edit', false) },

    handleCollapse(val) { this.collapsed = val },

    handleTitleEdit(value) {
      this.$store.updateWidgetProp(this.widget_id, 'static', 'title', value)
    },

    changeSolid(value) {
      this.$store.updateWidgetProp(this.widget_id, 'static', 'solid', value)
    },

    handleEditVisible(value) {
      this.$store.updateWidgetProp(this.widget_id, 'dynamic', 'visible', value || undefined)
    },

    handleEditCollapsible(value) {
      this.$store.updateWidgetProp(this.widget_id, 'dynamic', 'collapsible', value || undefined)
    },

  },
}

</script>
