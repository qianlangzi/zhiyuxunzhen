<script setup lang="ts">
defineProps<{ modelValue?: number }>()
const emit = defineEmits<{ (e: 'update:modelValue', v: number | undefined): void }>()

/** 审核状态分类：全部 / 待审核(1) / 已通过(2) / 已驳回(3) */
const opts: { label: string; value: number | undefined }[] = [
  { label: '全部', value: undefined },
  { label: '待审核', value: 1 },
  { label: '已通过', value: 2 },
  { label: '已驳回', value: 3 },
]

const select = (v: number | undefined) => emit('update:modelValue', v)
</script>

<template>
  <div class="status-filter">
    <button
      v-for="opt in opts"
      :key="opt.label"
      class="filter-chip"
      :class="{ active: modelValue === opt.value }"
      @click="select(opt.value)"
    >
      {{ opt.label }}
    </button>
  </div>
</template>

<style scoped>
.status-filter {
  display: inline-flex;
  gap: 6px;
  padding: 4px;
  border-radius: 999px;
  background: var(--zy-surface-soft);
}

.filter-chip {
  padding: 6px 16px;
  border: none;
  border-radius: 999px;
  background: transparent;
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
  cursor: pointer;
  transition: all 160ms ease;
}

.filter-chip:hover {
  color: var(--zy-brand-strong);
}

.filter-chip.active {
  background: var(--zy-brand-strong);
  color: #fff;
  box-shadow: 0 4px 12px rgba(45, 110, 74, 0.22);
}
</style>