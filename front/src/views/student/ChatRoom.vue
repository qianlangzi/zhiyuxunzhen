<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { cases, chatMessages, reasoningNodes } from '../mockData'

const route = useRoute()
const draft = ref('')
const localMessages = ref([...chatMessages])

const selectedCase = computed(() => {
  const caseId = String(route.query.caseId || '')
  return cases.find((item) => item.id === caseId) || cases[0]
})

const examCost = computed(() => reasoningNodes.reduce((sum, node) => sum + (node.cost || 0), 0))

function sendMessage() {
  if (!draft.value.trim()) {
    ElMessage.warning('请输入问诊问题')
    return
  }
  localMessages.value.push({ by: 'student', text: draft.value.trim() })
  localMessages.value.push({ by: 'mentor', text: '已记录你的问题。下一步建议把症状时间线、诱因和缓解因素补全。' })
  draft.value = ''
}
</script>

<template>
  <main class="chat-layout">
    <section class="consult-card">
      <div class="page-head dark">
        <span>问诊室</span>
        <h1>和模拟病人对话</h1>
        <small>{{ selectedCase.title }} · {{ selectedCase.department }}</small>
      </div>

      <div class="message-list">
        <div v-for="msg in localMessages" :key="msg.text" class="message" :class="msg.by">
          <span>{{ msg.by === 'student' ? '学生' : msg.by === 'sp' ? '模拟病人' : '智能导师' }}</span>
          <p>{{ msg.text }}</p>
        </div>
      </div>

      <div class="room-input" aria-label="问诊输入区">
        <el-input
          v-model="draft"
          type="textarea"
          autosize
          placeholder="输入问诊问题，或提交你的初步诊断"
          aria-label="问诊问题"
          @keydown.enter.exact.prevent="sendMessage"
        />
        <el-button type="primary" @click="sendMessage">发送</el-button>
      </div>
    </section>

    <aside class="surface-card reasoning-card">
      <div class="page-head">
        <span>思维路径</span>
        <h2>诊断脑图</h2>
      </div>
      <div class="cost-box">
        <span>检查费用</span>
        <strong>¥{{ examCost }}</strong>
        <small>胸部 CT 已接近成本阈值，建议先确认低成本必要检查。</small>
      </div>
      <div class="node-list">
        <div v-for="node in reasoningNodes" :key="node.label" class="reason-node" :class="node.state">
          <small>{{ node.type }}</small>
          <strong>{{ node.label }}</strong>
          <span v-if="node.cost">¥{{ node.cost }}</span>
        </div>
      </div>
      <div class="reflection-box">
        <span>苏格拉底提示</span>
        <p>一级：你是否还需要确认胸痛与活动、体位的关系？</p>
        <p>二级：心电图 ST 段改变会如何影响你的判断？</p>
        <p>三级：训练结束后展示标准路径并标注脱轨点。</p>
      </div>
    </aside>
  </main>
</template>

<style scoped>
.chat-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.35fr) 360px;
  gap: 16px;
}

.consult-card {
  min-height: 620px;
  padding: 22px;
  border-radius: var(--zy-radius-xl);
  background: var(--zy-deep);
  color: #effffb;
  box-shadow: var(--zy-shadow);
}

.page-head h2 {
  margin: 6px 0 0;
  color: var(--zy-ink);
  font-size: 28px;
  line-height: 1.12;
}

.page-head.dark span,
.page-head.dark h1,
.page-head.dark small {
  color: #effffb;
}

.page-head.dark small {
  display: block;
  margin-top: 10px;
  color: rgba(239, 255, 251, 0.68);
  font-weight: 800;
}

.message-list {
  display: grid;
  gap: 12px;
  margin: 26px 0;
}

.message {
  max-width: 76%;
  padding: 14px 16px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.1);
}

.message.student {
  justify-self: end;
  background: var(--zy-brand);
}

.message.mentor {
  border: 1px solid rgba(255, 244, 223, 0.36);
  background: rgba(167, 99, 27, 0.2);
}

.message span {
  display: block;
  margin-bottom: 6px;
  color: rgba(239, 255, 251, 0.68);
  font-size: 12px;
  font-weight: 900;
}

.message p {
  margin: 0;
  color: #fff;
  line-height: 1.65;
}

.room-input {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-top: 32px;
  padding: 12px;
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.1);
}

.room-input :deep(.el-textarea__inner) {
  min-height: 44px !important;
  border: 0;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.94);
  resize: none;
}

.room-input .el-button {
  flex: 0 0 auto;
}

.reasoning-card {
  padding: 20px;
}

.cost-box {
  display: grid;
  gap: 6px;
  margin-top: 18px;
  padding: 14px;
  border: 1px solid rgba(167, 99, 27, 0.28);
  border-radius: var(--zy-radius-md);
  background: var(--zy-amber-soft);
}

.cost-box span,
.cost-box small,
.reflection-box span {
  color: var(--zy-muted);
  font-size: 12px;
  font-weight: 900;
}

.cost-box strong {
  color: var(--zy-warning);
  font-size: 26px;
}

.node-list {
  display: grid;
  gap: 12px;
  margin-top: 18px;
}

.reason-node {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  padding: 14px;
  border: 1px solid var(--zy-line);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.66);
  color: var(--zy-ink);
  font-weight: 900;
}

.reason-node small {
  display: block;
  grid-column: 1 / -1;
  margin-bottom: 4px;
  color: var(--zy-muted);
  font-size: 12px;
}

.reason-node.next {
  border-color: rgba(15, 76, 92, 0.34);
  background: var(--zy-brand-soft);
}

.reason-node.excluded {
  border-color: rgba(194, 65, 58, 0.24);
  background: rgba(194, 65, 58, 0.08);
}

.reason-node.warning {
  border-color: rgba(167, 99, 27, 0.28);
  background: var(--zy-amber-soft);
}

.reflection-box {
  display: grid;
  gap: 8px;
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid var(--zy-line);
}

.reflection-box p {
  margin: 0;
  color: var(--zy-muted);
  font-size: 13px;
  line-height: 1.6;
}

@media (max-width: 1080px) {
  .chat-layout {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .message {
    max-width: 92%;
  }

  .room-input {
    align-items: stretch;
    flex-direction: column;
  }
}
</style>
