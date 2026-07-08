export type ReviewItem = {
  id: number
  student: string
  assignment: string
  score: number
  issue: string
  status: string
}

export const cases = [
  {
    id: 'copd-acute',
    title: '慢阻肺急性加重',
    chief: '反复咳嗽、咳痰 10 年，加重伴气促 3 天',
    tags: ['呼吸系统', '低氧血症', '肺功能'],
    department: '呼吸系统',
    referenceCount: 28,
    rating: 4.7,
    certified: true,
    duration: '15 分钟',
    difficulty: '进阶'
  },
  {
    id: 'chest-pain',
    title: '胸痛待查',
    chief: '突发胸骨后压榨样疼痛 2 小时',
    tags: ['心血管', '心电图', '鉴别诊断'],
    department: '心血管',
    referenceCount: 43,
    rating: 4.9,
    certified: true,
    duration: '18 分钟',
    difficulty: '高阶'
  },
  {
    id: 'gi-bleeding',
    title: '上消化道出血',
    chief: '黑便 2 天，伴头晕乏力',
    tags: ['消化系统', '休克评估', '病史采集'],
    department: '消化系统',
    referenceCount: 16,
    rating: 4.4,
    certified: false,
    duration: '12 分钟',
    difficulty: '基础'
  }
]

export const chatMessages = [
  { by: 'student', text: '您好，我想先确认这次气促是活动后明显，还是安静时也存在？' },
  { by: 'sp', text: '上楼会明显喘，昨晚平躺也觉得憋，需要垫高枕头。' },
  { by: 'mentor', text: '你已经问到端坐呼吸线索，建议继续追问夜间憋醒。' }
]

export const reasoningNodes = [
  { label: '气促', type: '症状', state: 'queried' },
  { label: '端坐呼吸', type: '症状', state: 'active' },
  { label: '血常规', type: '检查', state: 'done', cost: 35 },
  { label: '心电图', type: '检查', state: 'next', cost: 30 },
  { label: '胸部 CT', type: '检查', state: 'warning', cost: 460 },
  { label: '肺炎', type: '诊断', state: 'excluded' },
  { label: '心衰', type: '诊断', state: 'next' }
]

export const abilityScores = [
  { label: '病史采集', value: 82 },
  { label: '诊断逻辑', value: 68 },
  { label: '沟通技巧', value: 88 },
  { label: '人文关怀', value: 76 }
]

export const learningPath = [
  { title: '心衰问诊补救病例', meta: '12 分钟 · 简单病例', progress: 35 },
  { title: '胸痛鉴别诊断切片', meta: '教材第 4 章 · 500 字', progress: 64 },
  { title: '血常规判读关卡', meta: '检验指标 · 8 道题', progress: 20 }
]

export const assignments = [
  {
    title: '内科问诊训练 01',
    className: '临床 2203 班',
    submitted: 37,
    total: 42,
    due: '今晚 22:00',
    status: '进行中',
    requireRecord: true,
    variable: '同病不同检验值'
  },
  {
    title: '胸痛鉴别诊断',
    className: '规培一组',
    submitted: 18,
    total: 24,
    due: '明天 18:00',
    status: 'AI 批阅中',
    requireRecord: true,
    variable: '年龄与并发症随机'
  },
  {
    title: '消化系统大病历',
    className: '临床 2201 班',
    submitted: 41,
    total: 45,
    due: '周五 12:00',
    status: '待复核',
    requireRecord: true,
    variable: '关闭'
  }
]

export const reviewQueue: ReviewItem[] = [
  {
    id: 1,
    student: '林同学',
    assignment: '胸痛鉴别诊断',
    score: 82,
    issue: '现病史遗漏放射痛方向，未开心电图',
    status: '待复核'
  },
  {
    id: 2,
    student: '周同学',
    assignment: '慢阻肺急性加重',
    score: 76,
    issue: '体征记录缺少桶状胸和肺部啰音描述',
    status: '已初步批阅'
  },
  {
    id: 3,
    student: '陈同学',
    assignment: '消化系统大病历',
    score: 89,
    issue: '诊断推理完整，需人工确认用药史',
    status: '有争议项'
  }
]

export const weakness = [
  { tag: '心衰', avg: 0.52, count: 18 },
  { tag: '胸痛鉴别', avg: 0.58, count: 21 },
  { tag: '血常规判读', avg: 0.61, count: 14 },
  { tag: '肺水肿', avg: 0.49, count: 11 }
]

export const dailyCase = {
  title: '每日一例：活动后胸闷',
  summary: '男，59 岁，活动后胸闷 3 个月，近 1 周加重。既往高血压 8 年。',
  options: ['稳定型心绞痛', '支气管哮喘', '急性胃炎', '肺结核'],
  requiredExam: '心电图',
  avoidExam: '无指征胸部增强 CT',
  source: '《内科学》第 3 章，心血管系统，P128'
}

export const heatmapDays = Array.from({ length: 84 }, (_, index) => {
  const value = (index * 7 + 3) % 5
  return {
    date: `D-${83 - index}`,
    value
  }
})

export const mistakes = [
  {
    type: '诊断错误',
    title: '胸痛病例误判为胃炎',
    tag: '胸痛鉴别',
    evidence: '遗漏胸骨后压榨痛、出汗、心电图检查',
    status: '未复习'
  },
  {
    type: '漏问病史',
    title: '慢阻肺病例未追问夜间憋醒',
    tag: '心衰',
    evidence: '端坐呼吸已经出现，但未继续确认 PND',
    status: '已复习'
  },
  {
    type: '检查错误',
    title: '优先选择高价 CT',
    tag: '卫生经济学',
    evidence: '未完成低成本必要检查前开立胸部增强 CT',
    status: '未复习'
  }
]

export const formatShieldRules = [
  { label: '主诉 20 字以内', state: '通过', detail: '包含主要症状和持续时间' },
  { label: '过敏史不可为空', state: '打回', detail: '未知需填写“否认”或“不详”' },
  { label: '现病史时间线', state: '提示', detail: '建议补充症状发展和就诊经过' }
]

export const marketCases = [
  {
    title: '胸痛三联鉴别训练',
    author: '心内科教研组',
    department: '心血管',
    difficulty: '高阶',
    referenceCount: 73,
    rating: 4.9,
    certified: true
  },
  {
    title: '发热伴咳嗽分层问诊',
    author: '呼吸内科教研组',
    department: '呼吸系统',
    difficulty: '进阶',
    referenceCount: 51,
    rating: 4.8,
    certified: true
  },
  {
    title: '黑便与贫血综合病例',
    author: '消化内科李老师',
    department: '消化系统',
    difficulty: '标准',
    referenceCount: 24,
    rating: 4.5,
    certified: false
  }
]

export const adminStats = [
  { label: '今日活跃', value: '486', detail: '学生 421，教师 65' },
  { label: 'Token 预估', value: '128k', detail: '较昨日 +8.4%' },
  { label: '待审核', value: '17', detail: '病例 9，教师 8' },
  { label: '模型成功率', value: '99.2%', detail: '平均首 Token 1.1s' }
]

export const teacherAudits = [
  { name: '张明', org: '附属一院心内科', credential: '执业医师证已上传', status: '待审核' },
  { name: '李倩', org: '附属二院呼吸科', credential: '教学授权材料已上传', status: '待审核' },
  { name: '王瑜', org: '校本部内科教研室', credential: '工号认证', status: '已通过' }
]

export const caseAudits = [
  { title: '肺栓塞高危识别', owner: '呼吸内科教研组', risk: '需确认 D-二聚体阈值', status: '待审' },
  { title: '急性胰腺炎入院评估', owner: '消化内科李老师', risk: '无明显风险', status: '待审' },
  { title: '心衰急性加重', owner: '心内科教研组', risk: '已认证', status: '通过' }
]

export const auditLogs = [
  { time: '09:42', operator: 'admin01', action: '通过病例审核', target: '心衰急性加重' },
  { time: '10:18', operator: 'ops02', action: '切换备用模型', target: 'Spark Lite' },
  { time: '11:05', operator: 'admin01', action: '导出学情数据', target: '临床 2203 班' }
]
