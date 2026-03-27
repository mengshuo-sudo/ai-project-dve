<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import {
  createProjectEnvironment,
  deleteProjectEnvironment,
  fetchProjectEnvironments,
  updateProjectEnvironment,
  type ProjectEnvironment
} from '@/lib/aiTestingPlatformApi'

const route = useRoute()

const projectId = computed(() => {
  const raw = route.params.projectId
  if (typeof raw === 'string') return raw.trim()
  if (Array.isArray(raw) && typeof raw[0] === 'string') return raw[0].trim()
  return ''
})

const environments = ref<ProjectEnvironment[]>([])
const isLoading = ref(false)
const loadError = ref('')
const searchText = ref('')
const isSubmitting = ref(false)
const deletingId = ref('')
const isDialogOpen = ref(false)
const editingId = ref('')

const form = reactive({
  name: '',
  baseUrl: '',
  variablesText: '',
  secretsText: '',
  enableHealthCheck: false,
  healthUrl: '',
  timeoutMs: 5000,
  expectedStatus: 200
})

function resetForm() {
  form.name = ''
  form.baseUrl = ''
  form.variablesText = ''
  form.secretsText = ''
  form.enableHealthCheck = false
  form.healthUrl = ''
  form.timeoutMs = 5000
  form.expectedStatus = 200
}

function toLines(data: Record<string, string> | undefined) {
  const source = data && typeof data === 'object' ? data : {}
  return Object.entries(source)
    .map(([k, v]) => `${k}=${v}`)
    .join('\n')
}

function parseLines(text: string) {
  const out: Record<string, string> = {}
  for (const row of String(text || '').split('\n')) {
    const line = row.trim()
    if (!line) continue
    const idx = line.indexOf('=')
    if (idx <= 0) continue
    const key = line.slice(0, idx).trim()
    const value = line.slice(idx + 1).trim()
    if (!key) continue
    out[key] = value
  }
  return out
}

function formatTime(ts?: number | null) {
  if (!Number.isFinite(ts) || !ts) return '-'
  const value = Number(ts)
  const date = new Date(value > 1_000_000_000_000 ? value : value * 1000)
  return date.toLocaleString()
}

const filteredItems = computed(() => {
  const keyword = searchText.value.trim().toLowerCase()
  if (!keyword) return environments.value
  return environments.value.filter((item) => {
    const name = String(item.name || '').toLowerCase()
    const baseUrl = String(item.baseUrl || '').toLowerCase()
    return name.includes(keyword) || baseUrl.includes(keyword)
  })
})

const statTotal = computed(() => filteredItems.value.length)
const statHealthOn = computed(() => filteredItems.value.filter((item) => Boolean(item.healthCheck?.url)).length)
const statVars = computed(() =>
  filteredItems.value.reduce((acc, item) => acc + Object.keys(item.variables || {}).length, 0)
)
const statSecrets = computed(() =>
  filteredItems.value.reduce((acc, item) => acc + (item.secretKeys || []).length, 0)
)

async function loadList() {
  const pid = projectId.value
  if (!pid) {
    environments.value = []
    loadError.value = '缺少 projectId'
    return
  }
  isLoading.value = true
  loadError.value = ''
  try {
    environments.value = await fetchProjectEnvironments(pid)
  } catch (error) {
    environments.value = []
    loadError.value = error instanceof Error ? error.message : '加载环境失败'
  } finally {
    isLoading.value = false
  }
}

function openCreateDialog() {
  editingId.value = ''
  resetForm()
  isDialogOpen.value = true
}

function openEditDialog(item: ProjectEnvironment) {
  editingId.value = item.id
  form.name = String(item.name || '')
  form.baseUrl = String(item.baseUrl || '')
  form.variablesText = toLines(item.variables)
  form.secretsText = ''
  form.enableHealthCheck = Boolean(item.healthCheck?.url)
  form.healthUrl = String(item.healthCheck?.url || '')
  form.timeoutMs = Number(item.healthCheck?.timeoutMs || 5000)
  form.expectedStatus = Number(item.healthCheck?.expectedStatus || 200)
  isDialogOpen.value = true
}

function closeDialog() {
  isDialogOpen.value = false
  editingId.value = ''
  resetForm()
}

async function submitForm() {
  if (isSubmitting.value) return
  const pid = projectId.value
  if (!pid) return
  const name = form.name.trim()
  const baseUrl = form.baseUrl.trim()
  if (!name || !baseUrl) {
    window.alert('请填写环境名称和 Base URL')
    return
  }
  if (form.enableHealthCheck && !form.healthUrl.trim()) {
    window.alert('已开启健康检查时，检查 URL 不能为空')
    return
  }

  isSubmitting.value = true
  try {
    const variables = parseLines(form.variablesText)
    const secrets = parseLines(form.secretsText)
    const healthCheck = form.enableHealthCheck
      ? {
          url: form.healthUrl.trim(),
          timeoutMs: Math.max(1, Math.min(60000, Math.floor(Number(form.timeoutMs) || 5000))),
          expectedStatus: Math.max(100, Math.min(599, Math.floor(Number(form.expectedStatus) || 200)))
        }
      : null

    if (editingId.value) {
      const payload: {
        name: string
        baseUrl: string
        variables: Record<string, string>
        secrets?: Record<string, string>
        healthCheck: { url: string; timeoutMs: number; expectedStatus: number } | null
      } = {
        name,
        baseUrl,
        variables,
        healthCheck
      }
      if (Object.keys(secrets).length) payload.secrets = secrets
      await updateProjectEnvironment(pid, editingId.value, payload)
    } else {
      await createProjectEnvironment(pid, {
        name,
        baseUrl,
        variables,
        secrets,
        healthCheck
      })
    }
    await loadList()
    closeDialog()
  } catch (error) {
    const message = error instanceof Error ? error.message : '保存环境失败'
    window.alert(message)
  } finally {
    isSubmitting.value = false
  }
}

async function removeEnvironment(item: ProjectEnvironment) {
  const pid = projectId.value
  if (!pid) return
  const confirmed = window.confirm(`确认删除环境「${item.name}」吗？`)
  if (!confirmed) return
  deletingId.value = item.id
  try {
    await deleteProjectEnvironment(pid, item.id)
    await loadList()
  } catch (error) {
    const message = error instanceof Error ? error.message : '删除环境失败'
    window.alert(message)
  } finally {
    deletingId.value = ''
  }
}

watch(
  projectId,
  () => {
    void loadList()
  },
  { immediate: true }
)
</script>

<template>
  <div class="w-full bg-[rgba(236,236,240,0.3)] md:pr-[16.67px]">
    <div class="flex flex-col gap-[16px] px-[16px] pt-[16px] md:px-[24px] md:pt-[24px]">
      <div class="flex flex-col gap-[12px] md:flex-row md:items-center md:justify-between md:gap-0">
        <div class="flex flex-col gap-[2px]">
          <div class="text-[18px] font-semibold leading-[28px] text-[#0A0A0A]">环境管理</div>
          <div class="text-[14px] leading-[20px] text-[#717182]">管理环境地址、变量与密钥配置</div>
        </div>
        <div class="flex items-center gap-[8px]">
          <button
            type="button"
            class="h-[32px] rounded-[10px] border border-black/10 bg-white px-[12px] text-[14px] font-medium leading-[20px] text-[#0A0A0A]"
            :disabled="isLoading"
            @click="loadList"
          >
            {{ isLoading ? '刷新中...' : '刷新' }}
          </button>
          <button type="button" class="h-[32px] rounded-[10px] bg-[#155DFC] px-[12px] text-[14px] font-medium leading-[20px] text-white" @click="openCreateDialog">
            新建环境
          </button>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-[8px] md:grid-cols-4">
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">环境总数</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statTotal }}</div>
        </div>
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">启用健康检查</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statHealthOn }}</div>
        </div>
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">变量总数</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statVars }}</div>
        </div>
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">密钥总数</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statSecrets }}</div>
        </div>
      </div>

      <div class="relative h-[36px] w-full max-w-[384px] rounded-[10px] border border-black/10 bg-white px-[12px]">
        <input
          v-model="searchText"
          class="h-full w-full bg-transparent text-[14px] leading-[20px] text-[#0A0A0A] outline-none"
          placeholder="搜索环境名称或 Base URL"
          type="text"
        />
      </div>

      <div class="overflow-hidden rounded-[14px] border border-black/10 bg-white">
        <div class="grid grid-cols-12 border-b border-black/10 bg-[#FAFAFA] px-[12px] py-[10px] text-[12px] leading-[16px] text-[#717182]">
          <div class="col-span-2">环境名称</div>
          <div class="col-span-4">Base URL</div>
          <div class="col-span-1 text-center">变量</div>
          <div class="col-span-1 text-center">密钥</div>
          <div class="col-span-2">健康检查</div>
          <div class="col-span-1">更新时间</div>
          <div class="col-span-1 text-right">操作</div>
        </div>

        <div v-if="isLoading" class="px-[12px] py-[24px] text-[13px] leading-[20px] text-[#717182]">加载中...</div>
        <div v-else-if="loadError" class="px-[12px] py-[24px] text-[13px] leading-[20px] text-[#DC2626]">{{ loadError }}</div>
        <div v-else-if="!filteredItems.length" class="px-[12px] py-[24px] text-[13px] leading-[20px] text-[#717182]">暂无环境数据</div>

        <div v-for="item in filteredItems" :key="item.id" class="grid grid-cols-12 items-center border-b border-black/5 px-[12px] py-[10px] last:border-b-0">
          <div class="col-span-2 truncate text-[13px] font-medium leading-[20px] text-[#0A0A0A]" :title="item.name">{{ item.name }}</div>
          <div class="col-span-4 truncate text-[13px] leading-[20px] text-[#52525B]" :title="item.baseUrl">{{ item.baseUrl }}</div>
          <div class="col-span-1 text-center text-[13px] leading-[20px] text-[#0A0A0A]">{{ Object.keys(item.variables || {}).length }}</div>
          <div class="col-span-1 text-center text-[13px] leading-[20px] text-[#0A0A0A]">{{ (item.secretKeys || []).length }}</div>
          <div class="col-span-2 truncate text-[12px] leading-[16px] text-[#717182]" :title="item.healthCheck?.url || ''">
            {{ item.healthCheck?.url ? `${item.healthCheck.expectedStatus} / ${item.healthCheck.timeoutMs}ms` : '未配置' }}
          </div>
          <div class="col-span-1 text-[12px] leading-[16px] text-[#717182]">{{ formatTime(item.updatedAt) }}</div>
          <div class="col-span-1 flex justify-end gap-[6px]">
            <button type="button" class="h-[28px] rounded-[8px] border border-black/10 px-[8px] text-[12px] leading-[18px] text-[#0A0A0A]" @click="openEditDialog(item)">
              编辑
            </button>
            <button
              type="button"
              class="h-[28px] rounded-[8px] border border-[#FCA5A5] px-[8px] text-[12px] leading-[18px] text-[#DC2626]"
              :disabled="deletingId === item.id"
              @click="removeEnvironment(item)"
            >
              {{ deletingId === item.id ? '删除中' : '删除' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div v-if="isDialogOpen" class="fixed inset-0 z-50 flex items-center justify-center">
    <button class="absolute inset-0 bg-black/40" type="button" aria-label="Close" @click="closeDialog" />
    <div class="relative w-full max-w-[calc(100vw-32px)] overflow-hidden rounded-[16px] border border-black/10 bg-white shadow-[0px_25px_50px_-12px_rgba(0,0,0,0.25)] sm:w-[680px] sm:max-w-[680px]">
      <div class="border-b border-black/10 px-[20px] py-[14px] text-[16px] font-semibold leading-[24px] text-[#0A0A0A]">
        {{ editingId ? '编辑环境' : '新建环境' }}
      </div>
      <div class="grid grid-cols-1 gap-[12px] px-[20px] py-[16px] md:grid-cols-2">
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">环境名称</div>
          <input v-model="form.name" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="text" placeholder="如：开发环境" />
        </div>
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">Base URL</div>
          <input v-model="form.baseUrl" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="text" placeholder="https://api.example.com" />
        </div>
        <div class="md:col-span-2 flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">变量（每行 key=value）</div>
          <textarea v-model="form.variablesText" class="h-[88px] rounded-[10px] border border-black/10 px-[10px] py-[8px] text-[13px] outline-none" placeholder="tenant=demo&#10;region=cn" />
        </div>
        <div class="md:col-span-2 flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">密钥（每行 key=value）</div>
          <textarea v-model="form.secretsText" class="h-[88px] rounded-[10px] border border-black/10 px-[10px] py-[8px] text-[13px] outline-none" placeholder="token=***&#10;clientSecret=***" />
        </div>
        <div class="md:col-span-2 flex items-center gap-[8px]">
          <input id="enable-health-check" v-model="form.enableHealthCheck" type="checkbox" />
          <label class="text-[13px] leading-[18px] text-[#0A0A0A]" for="enable-health-check">启用健康检查</label>
        </div>
        <template v-if="form.enableHealthCheck">
          <div class="md:col-span-2 flex flex-col gap-[6px]">
            <div class="text-[13px] leading-[18px] text-[#0A0A0A]">健康检查 URL</div>
            <input v-model="form.healthUrl" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="text" placeholder="https://api.example.com/health" />
          </div>
          <div class="flex flex-col gap-[6px]">
            <div class="text-[13px] leading-[18px] text-[#0A0A0A]">超时（ms）</div>
            <input v-model.number="form.timeoutMs" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="number" min="1" max="60000" />
          </div>
          <div class="flex flex-col gap-[6px]">
            <div class="text-[13px] leading-[18px] text-[#0A0A0A]">期望状态码</div>
            <input v-model.number="form.expectedStatus" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="number" min="100" max="599" />
          </div>
        </template>
      </div>
      <div class="flex items-center justify-end gap-[8px] border-t border-black/10 px-[20px] py-[12px]">
        <button type="button" class="h-[34px] rounded-[10px] border border-black/10 px-[12px] text-[13px] text-[#0A0A0A]" @click="closeDialog">取消</button>
        <button type="button" class="h-[34px] rounded-[10px] bg-[#155DFC] px-[12px] text-[13px] text-white" :disabled="isSubmitting" @click="submitForm">
          {{ isSubmitting ? '保存中...' : '保存' }}
        </button>
      </div>
    </div>
  </div>
</template>
