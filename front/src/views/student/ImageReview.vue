<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import type { UploadFile } from 'element-plus'
import { ElMessage } from 'element-plus'

const imageUrl = ref('')
const finding = ref('')
const selection = ref({ x: 62, y: 56 })
const submitted = ref(false)

const selectionText = computed(
  () => `已圈选影像区域，横向 ${selection.value.x}%，纵向 ${selection.value.y}%`
)

function handleUpload(file: UploadFile) {
  const raw = file.raw
  if (!raw) return
  if (!raw.type.startsWith('image/')) {
    ElMessage.warning('请上传图片格式的影像资料')
    return
  }
  if (raw.size > 8 * 1024 * 1024) {
    ElMessage.warning('图片请控制在 8MB 以内')
    return
  }

  if (imageUrl.value) URL.revokeObjectURL(imageUrl.value)
  imageUrl.value = URL.createObjectURL(raw)
  submitted.value = false
}

function placeSelection(event: MouseEvent) {
  const target = event.currentTarget as HTMLElement
  const rect = target.getBoundingClientRect()
  const x = Math.round(((event.clientX - rect.left) / rect.width) * 100)
  const y = Math.round(((event.clientY - rect.top) / rect.height) * 100)
  selection.value = {
    x: Math.min(88, Math.max(12, x)),
    y: Math.min(84, Math.max(16, y))
  }
  submitted.value = false
}

function moveSelection(event: KeyboardEvent) {
  const step = event.shiftKey ? 8 : 3
  const next = { ...selection.value }

  if (event.key === 'ArrowLeft') next.x -= step
  else if (event.key === 'ArrowRight') next.x += step
  else if (event.key === 'ArrowUp') next.y -= step
  else if (event.key === 'ArrowDown') next.y += step
  else return

  event.preventDefault()
  selection.value = {
    x: Math.min(88, Math.max(12, next.x)),
    y: Math.min(84, Math.max(16, next.y))
  }
  submitted.value = false
}

function submitReview() {
  if (!imageUrl.value) {
    ElMessage.warning('请先上传影像资料')
    return
  }

  if (!finding.value.trim()) {
    ElMessage.warning('请先填写你的判读意见')
    return
  }

  submitted.value = true
  ElMessage.success('影像判读已保存')
}

onBeforeUnmount(() => {
  if (imageUrl.value) URL.revokeObjectURL(imageUrl.value)
})
</script>

<template>
  <main class="image-page">
    <section class="surface-card scan-card">
      <div class="scan-workspace">
        <div
          class="scan-preview"
          role="slider"
          tabindex="0"
          :aria-valuenow="selection.x"
          aria-valuemin="12"
          aria-valuemax="88"
          :aria-valuetext="selectionText"
          aria-label="影像圈选区域横向位置，点击预览或使用方向键移动"
          @click="placeSelection"
          @keydown="moveSelection"
        >
          <img v-if="imageUrl" :src="imageUrl" alt="已上传的影像资料" />
          <div v-else class="empty-scan">
            <el-icon><Picture /></el-icon>
            <strong>请上传胸片、CT 截图或心电图图片</strong>
            <span>上传后点击图像标记可疑位置</span>
          </div>
          <span
            v-if="imageUrl"
            class="selection-box"
            :style="{ left: `${selection.x}%`, top: `${selection.y}%` }"
          ></span>
          <span class="scan-label">{{ selectionText }}</span>
        </div>

        <el-upload accept="image/*" :auto-upload="false" :show-file-list="false" :on-change="handleUpload">
          <el-button plain>
            <el-icon><Upload /></el-icon>
            上传影像
          </el-button>
        </el-upload>
      </div>

      <div>
        <span class="eyebrow">影像判读</span>
        <h1>圈出可疑区域</h1>
        <p>上传影像后，点击预览区圈出你认为异常的位置，也可以用方向键微调。提交后老师可以看到你的判读位置和理由。</p>

        <el-form class="review-form" label-position="top">
          <el-form-item label="判读意见">
            <el-input
              v-model="finding"
              type="textarea"
              :rows="4"
              maxlength="160"
              show-word-limit
              placeholder="例如：右下肺野可见片状高密度影，建议结合症状和听诊结果判断。"
            />
          </el-form-item>
          <el-button type="primary" @click="submitReview">提交判读</el-button>
        </el-form>

        <div class="note" :class="{ saved: submitted }" aria-live="polite">
          <strong>{{ submitted ? '判读已保存' : '圈选范围已记录' }}</strong>
          <span>{{ selectionText }}</span>
        </div>
      </div>
    </section>
  </main>
</template>

<style scoped>
.image-page {
  display: grid;
}

.scan-card {
  display: grid;
  grid-template-columns: minmax(0, 1.1fr) 360px;
  gap: 22px;
  align-items: center;
  padding: 20px;
}

.scan-workspace {
  display: grid;
  gap: 12px;
}

.scan-preview {
  position: relative;
  min-height: 420px;
  overflow: hidden;
  border-radius: 22px;
  border: 1px dashed rgba(15, 76, 92, 0.28);
  background: #f7fbfa;
  cursor: crosshair;
}

.scan-preview:focus-visible {
  outline: 3px solid rgba(15, 76, 92, 0.18);
  outline-offset: 3px;
}

.scan-preview img {
  width: 100%;
  height: 100%;
  min-height: 420px;
  object-fit: cover;
  filter: grayscale(1) contrast(1.08);
}

.empty-scan {
  display: grid;
  place-items: center;
  align-content: center;
  gap: 10px;
  min-height: 420px;
  padding: 24px;
  color: var(--zy-muted);
  text-align: center;
}

.empty-scan .el-icon {
  color: var(--zy-brand);
  font-size: 42px;
}

.empty-scan strong {
  color: var(--zy-ink);
  font-size: 16px;
}

.empty-scan span {
  font-size: 13px;
  font-weight: 800;
}

.selection-box {
  position: absolute;
  transform: translate(-50%, -50%);
  width: 120px;
  height: 86px;
  border: 2px solid #8fe1d3;
  border-radius: 18px;
  box-shadow: 0 0 0 999px rgba(7, 27, 34, 0.22);
  pointer-events: none;
  transition: left 180ms ease, top 180ms ease;
}

.scan-label {
  position: absolute;
  right: 16px;
  bottom: 16px;
  left: 16px;
  padding: 10px 12px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.9);
  color: var(--zy-ink);
  font-size: 13px;
  font-weight: 900;
}

.eyebrow {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

h1 {
  margin: 8px 0 12px;
  color: var(--zy-ink);
  font-size: clamp(26px, 3vw, 34px);
  line-height: 1.1;
}

p {
  margin: 0;
  color: var(--zy-muted);
  line-height: 1.75;
}

.review-form {
  margin-top: 18px;
}

.note {
  display: grid;
  gap: 6px;
  margin-top: 18px;
  padding: 14px;
  border: 1px solid rgba(15, 76, 92, 0.16);
  border-radius: 16px;
  background: rgba(223, 241, 243, 0.72);
}

.note.saved {
  background: rgba(224, 246, 232, 0.84);
}

.note strong,
.note span {
  display: block;
}

.note span {
  color: var(--zy-muted);
}

@media (max-width: 980px) {
  .scan-card {
    grid-template-columns: 1fr;
  }
}
</style>
