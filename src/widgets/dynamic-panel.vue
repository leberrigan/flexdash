<!-- DynamicPanel - Renders a list of child widgets driven by a server data variable.
     Each element of the 'widgets' prop specifies a widget kind and its properties.
     Dynamic per-child bindings use a 'dynamic' sub-object:
       { kind: "Stat", title: "Temp", dynamic: { value: "sensors/temp" } }
     Copyright ©2024 Thorsten von Eicken, MIT license, see LICENSE file
-->

<template>
  <div :class="['dynamic-panel', { 'v-card': card }]">
    <dynamic-child
      v-for="(item, ix) in widgets"
      :key="ix"
      :config="item"
    />
  </div>
</template>

<style scoped>
.dynamic-panel {
  width: 100%;
  flex-grow: 1;
  min-height: 0;
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 4px;
  overflow-y: auto;
  padding: 4px;
  align-content: start;
}
.v-card.dynamic-panel {
  overflow: visible;
}
</style>

<script>
import { h, resolveComponent } from 'vue'
import { walkTree } from '/src/store.js'

const DynamicChild = {
  name: 'DynamicChild',
  inject: ['$store', '$conn'],

  props: {
    config: { type: Object, required: true },
  },

  data() {
    return { bindings: {}, watchers: [] }
  },

  watch: {
    config: {
      immediate: true,
      deep: true,
      handler(config) { this.genBindings(config) },
    },
  },

  methods: {
    addDynBinding(key, var_name) {
      if (!var_name || typeof var_name !== 'string') return () => {}
      let path = var_name.split('/').filter(t => t.length > 0)
      if (path.length === 0) return () => {}
      const n = path.pop()
      const self = this
      return this.$watch(
        () => walkTree(this.$store.sd, path)[n],
        (newVal) => { self.bindings[key] = newVal },
        { deep: true, immediate: true }
      )
    },

    genBindings(config) {
      this.watchers.forEach(w => w())
      this.watchers = []
      this.bindings = {}
      if (!config) return
      for (const k in (config.static || {})) {
        this.bindings[k] = config.static[k]
      }
      for (const k in (config.dynamic || {})) {
        this.watchers.push(this.addDynBinding(k, config.dynamic[k]))
      }
      if (config.output) {
        const output = config.output
        const conn = this.$conn
        this.bindings['onSend'] = (data) => conn?.serverSend(output, data)
      }
    },
  },

  beforeUnmount() { this.watchers.forEach(w => w()) },

  render() {
    const comp = resolveComponent(this.config?.kind || 'Stat')
    const config = this.config || {}
    const cols = config.cols || 1
    const hasTitle = 'title' in config
    const children = [
      hasTitle && h('div', { class: 'text-caption text-center px-1 pt-1 flex-shrink-0' }, config.title),
      h(comp, this.bindings),
    ].filter(Boolean)
    return h('div', { style: { gridColumn: `span ${cols}`, minHeight: 0, display: 'flex', flexDirection: 'column', alignItems: 'center' } },
      children
    )
  },
}

export default {
  name: 'DynamicPanel',
  help: `Container widget that renders child widgets driven by a server data variable.
Bind 'widgets' to a server variable containing an array of widget configurations.
Each item specifies the widget kind and its props. Use a 'dynamic' sub-object for
reactive per-child bindings: { "kind": "Stat", "title": "Temp", "dynamic": { "value": "sensors/temp" } }`,

  components: { DynamicChild },

  props: {
    widgets: { type: Array, default: () => [] },
    card:    { type: Boolean, default: false },
  },
}
</script>
