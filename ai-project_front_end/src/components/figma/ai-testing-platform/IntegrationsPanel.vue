<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { useRoute } from 'vue-router'

type IntegrationType = 'WEBHOOK' | 'FEISHU' | 'DINGTALK' | 'JIRA' | 'GITLAB'
type IntegrationStatus = 'CONNECTED' | 'DISCONNECTED'

type IntegrationItem = {
  id: string
  name: string
  type: IntegrationType
  description: string
  status: IntegrationStatus
  enabled: boolean
  updatedAt: string
  config: Record<string, string>
}

const route = useRoute()

const searchText = ref('')
const typeFilter = ref<'ALL' | IntegrationType>('ALL')
const statusFilter = ref<'ALL' | IntegrationStatus>('ALL')
const selectedId = ref('')
const isSaving = ref(false)
const isCreateDialogOpen = ref(false)

const integrations = ref<IntegrationItem[]>([
  {
    id: 'int-1',
    name: '默认 Webhook',
    type: 'WEBHOOK',
    description: '执行完成后推送通知到业务回调地址',
    status: 'CONNECTED',
    enabled: true,
    updatedAt: '2026-03-27 16:22',
    config: {
      endpoint: 'https://notify.example.com/webhook',
      secret: '******',
      events: 'run.finished,run.failed'
    }
  },
  {
    id: 'int-2',
    name: '飞书机器人',
    type: 'FEISHU',
    description: '把运行结果发送到飞书群',
    status: 'CONNECTED',
    enabled: true,
    updatedAt: '2026-03-27 15:03',
    config: {
      webhook: 'https://open.feishu.cn/open-apis/bot/v2/hook/******',
      signSecret: '******',
      atUsers: '@all'
    }
  },
  {
    id: 'int-3',
    name: 'Jira 缺陷同步',
    type: 'JIRA',
    description: '失败用例自动创建 Jira Issue',
    status: 'DISCONNECTED',
    enabled: false,
    updatedAt: '2026-03-26 21:16',
    config: {
      baseUrl: 'https://jira.example.com',
      projectKey: 'QA',
      auth: 'Bearer ******'
    }
  },
  {
    id: 'int-4',
    name: 'GitLab 提交状态',
    type: 'GITLAB',
    description: '将回归结果回写到 MR 状态检查',
    status: 'CONNECTED',
    enabled: true,
    updatedAt: '2026-03-26 18:04',
    config: {
      baseUrl: 'https://gitlab.example.com',
      token: 'glpat-******',
      projectId: '101'
    }
  },
  {
    id: 'int-5',
    name: '钉钉机器人',
    type: 'DINGTALK',
    description: '失败告警推送到钉钉群',
    status: 'DISCONNECTED',
    enabled: false,
    updatedAt: '2026-03-25 12:40',
    config: {
      webhook: 'https://oapi.dingtalk.com/robot/send?access_token=******',
      signSecret: '******',
      keyword: 'AI测试平台'
    }
  }
])

const editForm = reactive({
  name: '',
  enabled: false,
  field1: '',
  field2: '',
  field3: ''
})

const createForm = reactive({
  name: '',
  type: 'WEBHOOK' as IntegrationType,
  description: '',
  enabled: true,
  field1: '',
  field2: '',
  field3: ''
})

const typeLabelMap: Record<IntegrationType, string> = {
  WEBHOOK: 'Webhook',
  FEISHU: '飞书',
  DINGTALK: '钉钉',
  JIRA: 'Jira',
  GITLAB: 'GitLab'
}

const typeClassMap: Record<IntegrationType, string> = {
  WEBHOOK: 'bg-[#EFF6FF] text-[#1D4ED8]',
  FEISHU: 'bg-[#EEF2FF] text-[#4338CA]',
  DINGTALK: 'bg-[#FFF7ED] text-[#C2410C]',
  JIRA: 'bg-[#ECFDF5] text-[#047857]',
  GITLAB: 'bg-[#FEF3C7] text-[#92400E]'
}

const statusClassMap: Record<IntegrationStatus, string> = {
  CONNECTED: 'bg-[#DCFCE7] text-[#166534]',
  DISCONNECTED: 'bg-[#F3F4F6] text-[#52525B]'
}

function configKeysByType(type: IntegrationType) {
  if (type === 'WEBHOOK') return ['endpoint', 'secret', 'events']
  if (type === 'FEISHU') return ['webhook', 'signSecret', 'atUsers']
  if (type === 'DINGTALK') return ['webhook', 'signSecret', 'keyword']
  if (type === 'JIRA') return ['baseUrl', 'projectKey', 'auth']
  return ['baseUrl', 'token', 'projectId']
}

const filteredItems = computed(() => {
  const keyword = searchText.value.trim().toLowerCase()
  return integrations.value.filter((item) => {
    if (typeFilter.value !== 'ALL' && item.type !== typeFilter.value) return false
    if (statusFilter.value !== 'ALL' && item.status !== statusFilter.value) return false
    if (!keyword) return true
    const source = `${item.name} ${item.description} ${item.type}`.toLowerCase()
    return source.includes(keyword)
  })
})

const selectedItem = computed(() => integrations.value.find((item) => item.id === selectedId.value) || null)

const statTotal = computed(() => integrations.value.length)
const statConnected = computed(() => integrations.value.filter((item) => item.status === 'CONNECTED').length)
const statEnabled = computed(() => integrations.value.filter((item) => item.enabled).length)
const statDisconnected = computed(() => integrations.value.filter((item) => item.status === 'DISCONNECTED').length)

function syncEditForm(item: IntegrationItem | null) {
  if (!item) {
    editForm.name = ''
    editForm.enabled = false
    editForm.field1 = ''
    editForm.field2 = ''
    editForm.field3 = ''
    return
  }
  const entries = Object.entries(item.config)
  editForm.name = item.name
  editForm.enabled = item.enabled
  editForm.field1 = entries[0]?.[1] || ''
  editForm.field2 = entries[1]?.[1] || ''
  editForm.field3 = entries[2]?.[1] || ''
}

function selectItem(item: IntegrationItem) {
  selectedId.value = item.id
  syncEditForm(item)
}

function toggleEnabled(item: IntegrationItem) {
  item.enabled = !item.enabled
  item.status = item.enabled ? 'CONNECTED' : 'DISCONNECTED'
  item.updatedAt = new Date().toLocaleString()
  if (selectedId.value === item.id) {
    syncEditForm(item)
  }
}

function resetCreateForm() {
  createForm.name = ''
  createForm.type = 'WEBHOOK'
  createForm.description = ''
  createForm.enabled = true
  createForm.field1 = ''
  createForm.field2 = ''
  createForm.field3 = ''
}

function openCreateDialog() {
  resetCreateForm()
  isCreateDialogOpen.value = true
}

function closeCreateDialog() {
  isCreateDialogOpen.value = false
}

function createIntegration() {
  const name = createForm.name.trim()
  if (!name) {
    window.alert('请输入集成名称')
    return
  }
  const keys = configKeysByType(createForm.type)
  const now = new Date().toLocaleString()
  const item: IntegrationItem = {
    id: `int-${Date.now()}`,
    name,
    type: createForm.type,
    description: createForm.description.trim() || `${typeLabelMap[createForm.type]} 集成`,
    status: createForm.enabled ? 'CONNECTED' : 'DISCONNECTED',
    enabled: createForm.enabled,
    updatedAt: now,
    config: {
      [keys[0]]: createForm.field1.trim(),
      [keys[1]]: createForm.field2.trim(),
      [keys[2]]: createForm.field3.trim()
    }
  }
  integrations.value = [item, ...integrations.value]
  selectedId.value = item.id
  syncEditForm(item)
  closeCreateDialog()
}

async function saveCurrent() {
  if (!selectedItem.value) return
  isSaving.value = true
  try {
    const target = selectedItem.value
    target.name = editForm.name.trim() || target.name
    target.enabled = editForm.enabled
    target.status = target.enabled ? 'CONNECTED' : 'DISCONNECTED'
    const keys = Object.keys(target.config)
    const nextConfig: Record<string, string> = { ...target.config }
    if (keys[0]) nextConfig[keys[0]] = editForm.field1.trim()
    if (keys[1]) nextConfig[keys[1]] = editForm.field2.trim()
    if (keys[2]) nextConfig[keys[2]] = editForm.field3.trim()
    target.config = nextConfig
    target.updatedAt = new Date().toLocaleString()
    window.alert('配置已保存')
  } finally {
    isSaving.value = false
  }
}

if (integrations.value.length) {
  selectedId.value = integrations.value[0].id
  syncEditForm(integrations.value[0])
}
</script>

<template>
  <div class="w-full bg-[rgba(236,236,240,0.3)] md:pr-[16.67px]">
    <div class="flex flex-col gap-[16px] px-[16px] pt-[16px] md:px-[24px] md:pt-[24px]">
      <div class="flex flex-col gap-[12px] md:flex-row md:items-center md:justify-between md:gap-0">
        <div class="flex flex-col gap-[2px]">
          <div class="text-[18px] font-semibold leading-[28px] text-[#0A0A0A]">集成配置</div>
          <div class="text-[14px] leading-[20px] text-[#717182]">projectId: {{ String(route.params.projectId || '-') }} · 管理第三方平台通知、缺陷同步与状态回写</div>
        </div>
        <button type="button" class="h-[32px] rounded-[10px] bg-[#155DFC] px-[12px] text-[14px] font-medium leading-[20px] text-white" @click="openCreateDialog">
          添加配置
        </button>
      </div>

      <div class="grid grid-cols-2 gap-[8px] md:grid-cols-4">
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">集成总数</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statTotal }}</div>
        </div>
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">已连接</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statConnected }}</div>
        </div>
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">已启用</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statEnabled }}</div>
        </div>
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">未连接</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statDisconnected }}</div>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-[10px] rounded-[12px] border border-black/10 bg-white p-[12px] md:grid-cols-12">
        <div class="md:col-span-6">
          <div class="h-[36px] rounded-[10px] border border-black/10 px-[10px]">
            <input v-model="searchText" class="h-full w-full bg-transparent text-[13px] leading-[18px] text-[#0A0A0A] outline-none" placeholder="搜索集成名称或类型" type="text" />
          </div>
        </div>
        <div class="md:col-span-3">
          <select v-model="typeFilter" class="h-[36px] w-full rounded-[10px] border border-black/10 px-[10px] text-[13px] leading-[18px] text-[#0A0A0A] outline-none">
            <option value="ALL">全部类型</option>
            <option value="WEBHOOK">Webhook</option>
            <option value="FEISHU">飞书</option>
            <option value="DINGTALK">钉钉</option>
            <option value="JIRA">Jira</option>
            <option value="GITLAB">GitLab</option>
          </select>
        </div>
        <div class="md:col-span-3">
          <select v-model="statusFilter" class="h-[36px] w-full rounded-[10px] border border-black/10 px-[10px] text-[13px] leading-[18px] text-[#0A0A0A] outline-none">
            <option value="ALL">全部状态</option>
            <option value="CONNECTED">已连接</option>
            <option value="DISCONNECTED">未连接</option>
          </select>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-[12px] xl:grid-cols-12">
        <div class="overflow-hidden rounded-[14px] border border-black/10 bg-white xl:col-span-7">
          <div class="grid grid-cols-12 border-b border-black/10 bg-[#FAFAFA] px-[12px] py-[10px] text-[12px] leading-[16px] text-[#717182]">
            <div class="col-span-3">名称</div>
            <div class="col-span-2">类型</div>
            <div class="col-span-3">说明</div>
            <div class="col-span-2 text-center">状态</div>
            <div class="col-span-1 text-center">启用</div>
            <div class="col-span-1">更新时间</div>
          </div>

          <div v-if="!filteredItems.length" class="px-[12px] py-[24px] text-[13px] leading-[20px] text-[#717182]">暂无集成配置</div>

          <button
            v-for="item in filteredItems"
            :key="item.id"
            type="button"
            class="grid w-full grid-cols-12 items-center border-b border-black/5 px-[12px] py-[10px] text-left last:border-b-0"
            :class="selectedId === item.id ? 'bg-[#EFF6FF]' : 'hover:bg-[#FAFAFA]'"
            @click="selectItem(item)"
          >
            <div class="col-span-3 truncate text-[13px] font-medium leading-[18px] text-[#0A0A0A]" :title="item.name">{{ item.name }}</div>
            <div class="col-span-2">
              <span class="inline-flex rounded-[999px] px-[8px] py-[2px] text-[11px] leading-[14px]" :class="typeClassMap[item.type]">{{ typeLabelMap[item.type] }}</span>
            </div>
            <div class="col-span-3 truncate text-[12px] leading-[16px] text-[#52525B]" :title="item.description">{{ item.description }}</div>
            <div class="col-span-2 text-center">
              <span class="inline-flex rounded-[999px] px-[8px] py-[2px] text-[11px] leading-[14px]" :class="statusClassMap[item.status]">
                {{ item.status === 'CONNECTED' ? '已连接' : '未连接' }}
              </span>
            </div>
            <div class="col-span-1 flex justify-center">
              <input :checked="item.enabled" type="checkbox" @click.stop @change="toggleEnabled(item)" />
            </div>
            <div class="col-span-1 text-[11px] leading-[14px] text-[#717182]">{{ item.updatedAt }}</div>
          </button>
        </div>

        <div class="rounded-[14px] border border-black/10 bg-white xl:col-span-5">
          <div class="border-b border-black/10 px-[12px] py-[10px] text-[13px] font-medium leading-[18px] text-[#0A0A0A]">配置详情</div>
          <div v-if="!selectedItem" class="px-[12px] py-[24px] text-[13px] leading-[20px] text-[#717182]">请选择左侧集成项</div>
          <div v-else class="flex flex-col gap-[10px] px-[12px] py-[10px]">
            <div class="flex flex-col gap-[6px]">
              <div class="text-[12px] leading-[16px] text-[#717182]">集成名称</div>
              <input v-model="editForm.name" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[13px] outline-none" type="text" />
            </div>
            <div class="flex items-center gap-[8px]">
              <input v-model="editForm.enabled" type="checkbox" />
              <div class="text-[13px] leading-[18px] text-[#0A0A0A]">启用该集成</div>
            </div>
            <div class="flex flex-col gap-[6px]">
              <div class="text-[12px] leading-[16px] text-[#717182]">{{ Object.keys(selectedItem.config)[0] || '配置项 1' }}</div>
              <input v-model="editForm.field1" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[13px] outline-none" type="text" />
            </div>
            <div class="flex flex-col gap-[6px]">
              <div class="text-[12px] leading-[16px] text-[#717182]">{{ Object.keys(selectedItem.config)[1] || '配置项 2' }}</div>
              <input v-model="editForm.field2" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[13px] outline-none" type="text" />
            </div>
            <div class="flex flex-col gap-[6px]">
              <div class="text-[12px] leading-[16px] text-[#717182]">{{ Object.keys(selectedItem.config)[2] || '配置项 3' }}</div>
              <input v-model="editForm.field3" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[13px] outline-none" type="text" />
            </div>
            <button type="button" class="mt-[4px] h-[34px] rounded-[10px] bg-[#155DFC] px-[12px] text-[13px] font-medium leading-[18px] text-white" :disabled="isSaving" @click="saveCurrent">
              {{ isSaving ? '保存中...' : '保存配置' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div v-if="isCreateDialogOpen" class="fixed inset-0 z-50 flex items-center justify-center">
    <button class="absolute inset-0 bg-black/40" type="button" aria-label="Close" @click="closeCreateDialog" />
    <div class="relative w-full max-w-[calc(100vw-32px)] overflow-hidden rounded-[16px] border border-black/10 bg-white shadow-[0px_25px_50px_-12px_rgba(0,0,0,0.25)] sm:w-[620px] sm:max-w-[620px]">
      <div class="border-b border-black/10 px-[20px] py-[14px] text-[16px] font-semibold leading-[24px] text-[#0A0A0A]">添加配置</div>
      <div class="grid grid-cols-1 gap-[12px] px-[20px] py-[16px] md:grid-cols-2">
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">集成名称</div>
          <input v-model="createForm.name" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="text" placeholder="例如：生产告警 Webhook" />
        </div>
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">集成类型</div>
          <select v-model="createForm.type" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none">
            <option value="WEBHOOK">Webhook</option>
            <option value="FEISHU">飞书</option>
            <option value="DINGTALK">钉钉</option>
            <option value="JIRA">Jira</option>
            <option value="GITLAB">GitLab</option>
          </select>
        </div>
        <div class="md:col-span-2 flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">说明</div>
          <input v-model="createForm.description" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="text" placeholder="描述该集成用途" />
        </div>
        <div class="flex items-center gap-[8px] md:col-span-2">
          <input v-model="createForm.enabled" type="checkbox" />
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">创建后立即启用</div>
        </div>
        <div class="md:col-span-2 flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">{{ configKeysByType(createForm.type)[0] }}</div>
          <input v-model="createForm.field1" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="text" />
        </div>
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">{{ configKeysByType(createForm.type)[1] }}</div>
          <input v-model="createForm.field2" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="text" />
        </div>
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">{{ configKeysByType(createForm.type)[2] }}</div>
          <input v-model="createForm.field3" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="text" />
        </div>
      </div>
      <div class="flex items-center justify-end gap-[8px] border-t border-black/10 px-[20px] py-[12px]">
        <button type="button" class="h-[34px] rounded-[10px] border border-black/10 px-[12px] text-[13px] text-[#0A0A0A]" @click="closeCreateDialog">取消</button>
        <button type="button" class="h-[34px] rounded-[10px] bg-[#155DFC] px-[12px] text-[13px] text-white" @click="createIntegration">创建配置</button>
      </div>
    </div>
  </div>
</template>
