<!-- DynamicPanel - Renders a list of child widgets driven by a server data variable.
     Each element of the 'widgets' prop specifies a widget kind and its properties.
     Dynamic per-child bindings use a 'dynamic' sub-object:
       { kind: "Stat", title: "Temp", dynamic: { value: "sensors/temp" } }
     Copyright ©2024 Thorsten von Eicken, MIT license, see LICENSE file
-->

<template>
  <div class="dynamic-panel">
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
  display: flex;
  flex-direction: column;
  gap: 4px;
  overflow-y: auto;
  padding: 4px;
}
</style>

<script>
import { h, resolveComponent } from 'vue'
import { walkTree } from '/src/store.js'

const DynamicChild = {
  name: 'DynamicChild',
  inject: ['$store'],

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
      for (const k in config) {
        if (k !== 'kind' && k !== 'dynamic') this.bindings[k] = config[k]
      }
      for (const k in (config.dynamic || {})) {
        this.watchers.push(this.addDynBinding(k, config.dynamic[k]))
      }
    },
  },

  beforeUnmount() { this.watchers.forEach(w => w()) },

  render() {
    const comp = resolveComponent(this.config?.kind || 'Stat')
    return h(comp, this.bindings)
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
  },
}
</script>
