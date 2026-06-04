<!-- TopicTree - Display the dashboard topic tree with values so the user can pick one.
     Copyright ©2021 Thorsten von Eicken, MIT license, see LICENSE file
-->

<template>
  <!-- path text field -->
  <v-text-field clearable label="topic (/-separated path)"
                :model-value="modelValue"
                @update:modelValue="$emit('update:modelValue', $event)"
                append-inner-icon="mdi-file-tree"
                @click:append-inner="show_tree=!show_tree"
                v-bind="$attrs">
  </v-text-field>
  <!-- tree selector as an overlay -->
  <v-overlay v-model="show_tree" class="topic-tree">
    <v-card class="d-flex flex-column">
      <v-card-title class="d-flex width100 py-2 pb-0">
        <span>{{label}}</span>
        <v-spacer></v-spacer>
        <v-btn elevation=0 icon @click="tree=calcTree()">
          <v-icon>mdi-refresh</v-icon>
        </v-btn>
        <v-btn elevation=0 icon @click="show_tree=false">
          <v-icon>mdi-close</v-icon>
        </v-btn>
      </v-card-title>
      <v-list density="compact" class="flex-grow-1 overflow-y-auto">
        <v-list-item v-for="item in flatTree" :key="item.id"
            :style="`padding-left: ${item.depth * 16 + 8}px`"
            @click="item.children ? toggleOpen(item.id) : treeSelect(item.id)">
          <template #prepend v-if="item.children">
            <v-icon size="small">{{ openIds.includes(item.id) ? 'mdi-chevron-down' : 'mdi-chevron-right' }}</v-icon>
          </template>
          <v-list-item-title>{{ item.name }}</v-list-item-title>
        </v-list-item>
      </v-list>
    </v-card>
  </v-overlay>
</template>

<style>
.topic-tree .v-overlay__content { height: 95%; width: 95%; max-width: 400px; }
.topic-tree .v-card { height: 100%; }
.topic-tree .v-list { flex-grow: 1; overflow-y: scroll; }
</style>

<script scoped>

export default {
  name: "TopicTree",

  props: {
    label: { default: "path" },
    modelValue: { default: "" },
  },

  emits: [ 'update:modelValue' ],

  inject: ['$store'],

  data() { return {
    show_tree: false,
    tree: [],
    openIds: [],
  }},

  computed: {
    flatTree() {
      const items = []
      const flatten = (nodes, depth) => {
        for (const node of nodes) {
          items.push({ ...node, depth })
          if (node.children && this.openIds.includes(node.id)) {
            flatten(node.children, depth + 1)
          }
        }
      }
      flatten(this.tree, 0)
      return items
    },
  },

  mounted() {
    this.tree = this.calcTree()
  },

  methods: {

    toggleOpen(id) {
      const ix = this.openIds.indexOf(id)
      if (ix === -1) this.openIds.push(id)
      else this.openIds.splice(ix, 1)
    },

    // tree to feed into v-list, nodes have name, id, and optional children array
    calcTree() {
      function children(name, id, value) {
        let ret = null
        id = id === null ? name : id +'/' + name
        if (value === null || value === undefined) {
          ret = { name: `${name}: ${value}`, id }
        } else if (Array.isArray(value)) {
          ret = { name, id,
              children: Array.from(value).sort().map((v,ix) => children(ix.toString(), id, v)) }
        } else if (typeof value === 'object') {
          ret = { name, id,
              children: Object.entries(value).sort().map(([k,v])=> children(k, id, v)) }
        } else {
          ret = { name: `${name}: ${value}`, id }
        }
        return ret
      }

      return Object.entries(this.$store.sd).sort().map(([k,v])=> children(k, null, v))
    },

    treeSelect(id) {
      this.show_tree = false
      this.$emit('update:modelValue', id)
    },

  },
}
</script>
