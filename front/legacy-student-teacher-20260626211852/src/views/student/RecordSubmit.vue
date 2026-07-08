<template>
  <main class="page-shell">
    <section class="page-head">
      <span>大病历提交</span>
      <h1>整理问诊后的病历</h1>
    </section>

    <section class="surface-card record-card">
      <el-form label-position="top">
        <el-form-item label="病历正文">
          <el-input
            type="textarea"
            :rows="14"
            placeholder="填写主诉、现病史、既往史、体格检查、辅助检查和初步诊断"
          />
        </el-form-item>
        <div class="actions">
          <span>文本上限 5000 字</span>
          <el-button type="primary">提交批阅</el-button>
        </div>
      </el-form>
    </section>
  </main>
</template>

<style scoped>
.page-shell {
  display: grid;
  gap: 20px;
}

.page-head span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.page-head h1 {
  margin: 6px 0 0;
  color: var(--zy-ink);
  font-size: clamp(26px, 3vw, 34px);
}

.record-card {
  padding: 20px;
}

.actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.actions span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}
</style>
