<script setup lang="ts">
// 二级导航已提升为侧边栏树形菜单（pure-admin 风格），
// 本组件只保留简洁页头 + 子页容器，避免页面内重复占一排的卡片 tab。
</script>

<template>
  <main class="admin-page">
    <router-view v-slot="{ Component }">
      <transition name="page-fade" mode="out-in">
        <component :is="Component" :key="$route.path" />
      </transition>
    </router-view>
  </main>
</template>
