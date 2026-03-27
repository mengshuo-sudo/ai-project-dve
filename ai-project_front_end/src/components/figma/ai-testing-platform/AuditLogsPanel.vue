<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { useRoute } from 'vue-router'

type AuditLevel = 'INFO' | 'WARN' | 'ERROR'

type AuditItem = {
  id: string
  time: string
  operator: string
  operatorEmail: string
  module: string
  action: string
  resource: string
  level: AuditLevel
  ip: string
  detail: string
}

const route = useRoute()
const searchText = ref('')
const selectedModule = ref('ALL')
const selectedLevel = ref('ALL')
const dateRange = reactive({
  start: '',
  end: ''
})
const selectedLogId = ref('')

const logs = ref<AuditItem[]>([
  {
    id: 'log-1001',
    time: '2026-03-27 14:32:11',
    operator: '张晨',
    operatorEmail: 'chen.zhang@example.com',
    module: '成员权限',
    action: '更新角色权限',
    resource: '角色: 开发者',
    level: 'INFO',
    ip: '10.21.11.25',
    detail: '新增权限：run.manage，移除权限：project.settings'
  },
  {
    id: 'log-1002',
    time: '2026-03-27 13:58:04',
    operator: '李雅',
    operatorEmail: 'ya.li@example.com',
    module: '环境管理',
    action: '新建环境',
    resource: '环境: staging-cn',
    level: 'INFO',
    ip: '10.21.11.45',
    detail: '创建 Base URL=https://staging.api.example.com，配置变量 6 项'
  },
  {
    id: 'log-1003',
    time: '2026-03-27 13:12:39',
    operator: '系统',
    operatorEmail: 'system@platform.local',
    module: 'Worker 管理',
    action: 'Worker 心跳异常',
    resource: 'worker: linux-ci-03',
    level: 'WARN',
    ip: '127.0.0.1',
    detail: '连续 3 分钟未收到心跳，已标记为不可调度'
  },
  {
    id: 'log-1004',
    time: '2026-03-27 11:03:22',
    operator: '赵宁',
    operatorEmail: 'ning.zhao@example.com',
    module: '报告中心',
    action: '导出报告失败',
    resource: 'runId: run_20260327_085512',
    level: 'ERROR',
    ip: '10.21.12.66',
    detail: '导出任务超时，请稍后重试或联系管理员'
  }
])

const moduleOptions = computed(() => {
  const set = new Set(logs.value.map((item) => item.module))
  return ['ALL', ...Array.from(set)]
})

const filteredLogs = computed(() => {
  const keyword = searchText.value.trim().toLowerCase()
  const selectedStart = dateRange.start ? new Date(`${dateRange.start} 00:00:00`).getTime() : null
  const selectedEnd = dateRange.end ? new Date(`${dateRange.end} 23:59:59`).getTime() : null

  return logs.value.filter((item) => {
    if (selectedModule.value !== 'ALL' && item.module !== selectedModule.value) return false
    if (selectedLevel.value !== 'ALL' && item.level !== selectedLevel.value) return false

    const ts = new Date(item.time).getTime()
    if (selectedStart && ts < selectedStart) return false
    if (selectedEnd && ts > selectedEnd) return false

    if (!keyword) return true
    const content = `${item.operator} ${item.operatorEmail} ${item.module} ${item.action} ${item.resource} ${item.detail}`.toLowerCase()
    return content.includes(keyword)
  })
})

const selectedLog = computed(() => filteredLogs.value.find((item) => item.id === selectedLogId.value) || null)
const statTotal = computed(() => filteredLogs.value.length)
const statWarn = computed(() => filteredLogs.value.filter((item) => item.level === 'WARN').length)
const statError = computed(() => filteredLogs.value.filter((item) => item.level === 'ERROR').length)

const levelClassMap: Record<AuditLevel, string> = {
  INFO: 'bg-[#DBEAFE] text-[#1D4ED8]',
  WARN: 'bg-[#FEF3C7] text-[#92400E]',
  ERROR: 'bg-[#FEE2E2] text-[#B91C1C]'
}

function resetFilters() {
  searchText.value = ''
  selectedModule.value = 'ALL'
  selectedLevel.value = 'ALL'
  dateRange.start = ''
  dateRange.end = ''
}

function selectLog(item: AuditItem) {
  selectedLogId.value = item.id
}

function escapeCsvCell(value: string) {
  const raw = String(value ?? '')
  if (raw.includes(',') || raw.includes('"') || raw.includes('\n')) {
    return `"${raw.replace(/"/g, '""')}"`
  }
  return raw
}

function exportLogs() {
  const rows = filteredLogs.value
  if (!rows.length) {
    window.alert('当前筛选结果为空，无法导出')
    return
  }
  const header = ['时间', '操作人', '操作人邮箱', '模块', '动作', '资源', '级别', '来源IP', '详细描述']
  const lines = [
    header.map(escapeCsvCell).join(','),
    ...rows.map((item) =>
      [
        item.time,
        item.operator,
        item.operatorEmail,
        item.module,
        item.action,
        item.resource,
        item.level,
        item.ip,
        item.detail
      ]
        .map(escapeCsvCell)
        .join(',')
    )
  ]
  const csv = `\uFEFF${lines.join('\n')}`
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const now = new Date()
  const pad = (n: number) => String(n).padStart(2, '0')
  const stamp = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`
  const a = document.createElement('a')
  a.href = url
  a.download = `audit_logs_${stamp}.csv`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}
</script>

<template>
  <div class="w-full bg-[rgba(236,236,240,0.3)] md:pr-[16.67px]">
    <div class="flex flex-col gap-[16px] px-[16px] pt-[16px] md:px-[24px] md:pt-[24px]">
      <div class="flex flex-col gap-[12px] md:flex-row md:items-center md:justify-between md:gap-0">
        <div class="flex flex-col gap-[2px]">
          <div class="text-[18px] font-semibold leading-[28px] text-[#0A0A0A]">审计日志</div>
          <div class="text-[14px] leading-[20px] text-[#717182]">projectId: {{ String(route.params.projectId || '-') }} · 审计系统关键操作与变更事件</div>
        </div>
        <div class="flex items-center gap-[8px]">
          <button type="button" class="h-[32px] rounded-[10px] border border-black/10 bg-white px-[12px] text-[14px] font-medium leading-[20px] text-[#0A0A0A]" @click="exportLogs">
            导出日志
          </button>
          <button type="button" class="h-[32px] rounded-[10px] border border-black/10 bg-white px-[12px] text-[14px] font-medium leading-[20px] text-[#0A0A0A]" @click="resetFilters">
            重置筛选
          </button>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-[10px] rounded-[12px] border border-black/10 bg-white p-[12px] md:grid-cols-12">
        <div class="md:col-span-4">
          <div class="h-[36px] rounded-[10px] border border-black/10 px-[10px]">
            <input v-model="searchText" class="h-full w-full bg-transparent text-[13px] leading-[18px] text-[#0A0A0A] outline-none" placeholder="搜索操作人 / 模块 / 动作 / 资源" type="text" />
          </div>
        </div>
        <div class="md:col-span-2">
          <select v-model="selectedModule" class="h-[36px] w-full rounded-[10px] border border-black/10 px-[10px] text-[13px] leading-[18px] text-[#0A0A0A] outline-none">
            <option value="ALL">全部模块</option>
            <option v-for="module in moduleOptions.filter((v) => v !== 'ALL')" :key="module" :value="module">{{ module }}</option>
          </select>
        </div>
        <div class="md:col-span-2">
          <select v-model="selectedLevel" class="h-[36px] w-full rounded-[10px] border border-black/10 px-[10px] text-[13px] leading-[18px] text-[#0A0A0A] outline-none">
            <option value="ALL">全部级别</option>
            <option value="INFO">INFO</option>
            <option value="WARN">WARN</option>
            <option value="ERROR">ERROR</option>
          </select>
        </div>
        <div class="md:col-span-2">
          <input v-model="dateRange.start" class="h-[36px] w-full rounded-[10px] border border-black/10 px-[10px] text-[13px] leading-[18px] text-[#0A0A0A] outline-none" type="date" />
        </div>
        <div class="md:col-span-2">
          <input v-model="dateRange.end" class="h-[36px] w-full rounded-[10px] border border-black/10 px-[10px] text-[13px] leading-[18px] text-[#0A0A0A] outline-none" type="date" />
        </div>
      </div>

      <div class="grid grid-cols-3 gap-[8px]">
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">日志条目</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statTotal }}</div>
        </div>
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">WARN</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statWarn }}</div>
        </div>
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">ERROR</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statError }}</div>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-[12px] xl:grid-cols-12">
        <div class="overflow-hidden rounded-[14px] border border-black/10 bg-white xl:col-span-8">
          <div class="grid grid-cols-12 border-b border-black/10 bg-[#FAFAFA] px-[12px] py-[10px] text-[12px] leading-[16px] text-[#717182]">
            <div class="col-span-3">时间</div>
            <div class="col-span-2">操作人</div>
            <div class="col-span-2">模块</div>
            <div class="col-span-2">动作</div>
            <div class="col-span-2">资源</div>
            <div class="col-span-1 text-center">级别</div>
          </div>

          <div v-if="!filteredLogs.length" class="px-[12px] py-[24px] text-[13px] leading-[20px] text-[#717182]">
            暂无审计日志
          </div>

          <button
            v-for="item in filteredLogs"
            :key="item.id"
            type="button"
            class="grid w-full grid-cols-12 items-center border-b border-black/5 px-[12px] py-[10px] text-left last:border-b-0"
            :class="selectedLogId === item.id ? 'bg-[#EFF6FF]' : 'hover:bg-[#FAFAFA]'"
            @click="selectLog(item)"
          >
            <div class="col-span-3 text-[12px] leading-[16px] text-[#52525B]">{{ item.time }}</div>
            <div class="col-span-2 truncate text-[13px] leading-[18px] text-[#0A0A0A]" :title="`${item.operator} (${item.operatorEmail})`">{{ item.operator }}</div>
            <div class="col-span-2 truncate text-[13px] leading-[18px] text-[#52525B]" :title="item.module">{{ item.module }}</div>
            <div class="col-span-2 truncate text-[13px] leading-[18px] text-[#52525B]" :title="item.action">{{ item.action }}</div>
            <div class="col-span-2 truncate text-[13px] leading-[18px] text-[#52525B]" :title="item.resource">{{ item.resource }}</div>
            <div class="col-span-1 text-center">
              <span class="inline-flex rounded-[999px] px-[8px] py-[2px] text-[11px] leading-[14px]" :class="levelClassMap[item.level]">{{ item.level }}</span>
            </div>
          </button>
        </div>

        <div class="rounded-[14px] border border-black/10 bg-white xl:col-span-4">
          <div class="border-b border-black/10 px-[12px] py-[10px] text-[13px] font-medium leading-[18px] text-[#0A0A0A]">日志详情</div>
          <div v-if="!selectedLog" class="px-[12px] py-[24px] text-[13px] leading-[20px] text-[#717182]">选择左侧日志可查看详情</div>
          <div v-else class="flex flex-col gap-[10px] px-[12px] py-[10px]">
            <div class="rounded-[10px] border border-black/10 bg-[#FAFAFA] px-[10px] py-[8px]">
              <div class="text-[12px] leading-[16px] text-[#717182]">时间</div>
              <div class="mt-[2px] text-[13px] leading-[18px] text-[#0A0A0A]">{{ selectedLog.time }}</div>
            </div>
            <div class="rounded-[10px] border border-black/10 bg-[#FAFAFA] px-[10px] py-[8px]">
              <div class="text-[12px] leading-[16px] text-[#717182]">操作人</div>
              <div class="mt-[2px] text-[13px] leading-[18px] text-[#0A0A0A]">{{ selectedLog.operator }} · {{ selectedLog.operatorEmail }}</div>
            </div>
            <div class="rounded-[10px] border border-black/10 bg-[#FAFAFA] px-[10px] py-[8px]">
              <div class="text-[12px] leading-[16px] text-[#717182]">来源 IP</div>
              <div class="mt-[2px] text-[13px] leading-[18px] text-[#0A0A0A]">{{ selectedLog.ip }}</div>
            </div>
            <div class="rounded-[10px] border border-black/10 bg-[#FAFAFA] px-[10px] py-[8px]">
              <div class="text-[12px] leading-[16px] text-[#717182]">资源</div>
              <div class="mt-[2px] text-[13px] leading-[18px] text-[#0A0A0A]">{{ selectedLog.resource }}</div>
            </div>
            <div class="rounded-[10px] border border-black/10 bg-[#FAFAFA] px-[10px] py-[8px]">
              <div class="text-[12px] leading-[16px] text-[#717182]">详细描述</div>
              <div class="mt-[2px] whitespace-pre-wrap text-[13px] leading-[20px] text-[#0A0A0A]">{{ selectedLog.detail }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
