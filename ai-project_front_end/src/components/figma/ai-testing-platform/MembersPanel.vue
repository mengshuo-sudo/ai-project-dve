<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

type MemberStatus = 'ACTIVE' | 'PENDING' | 'DISABLED'

type RoleCatalogItem = {
  key: string
  name: string
  editable: boolean
}

type MemberItem = {
  id: string
  name: string
  email: string
  role: string
  status: MemberStatus
  team: string
  lastActiveAt: string
}

const router = useRouter()
const route = useRoute()
const roleStorageKey = 'ai-testing-platform.role-catalog'
const searchText = ref('')
const isInviteDialogOpen = ref(false)
const isRoleDialogOpen = ref(false)
const editingMemberId = ref('')
const deletingId = ref('')
const roleCatalog = ref<RoleCatalogItem[]>([])

const inviteForm = reactive({
  name: '',
  email: '',
  role: 'DEVELOPER',
  team: 'QA'
})

const roleForm = reactive({
  role: 'DEVELOPER',
  status: 'ACTIVE' as MemberStatus
})

const members = ref<MemberItem[]>([
  {
    id: 'm-1',
    name: '张晨',
    email: 'chen.zhang@example.com',
    role: 'ADMIN',
    status: 'ACTIVE',
    team: 'Platform',
    lastActiveAt: '2026-03-27 11:42'
  },
  {
    id: 'm-2',
    name: '李雅',
    email: 'ya.li@example.com',
    role: 'ADMIN',
    status: 'ACTIVE',
    team: 'QA',
    lastActiveAt: '2026-03-27 10:18'
  },
  {
    id: 'm-3',
    name: '王泽',
    email: 'ze.wang@example.com',
    role: 'DEVELOPER',
    status: 'PENDING',
    team: 'Service-A',
    lastActiveAt: '-'
  },
  {
    id: 'm-4',
    name: '赵宁',
    email: 'ning.zhao@example.com',
    role: 'VISITOR',
    status: 'DISABLED',
    team: 'Service-B',
    lastActiveAt: '2026-03-20 16:05'
  }
])

const fallbackRoles: RoleCatalogItem[] = [
  { key: 'DEVELOPER', name: '开发者', editable: false },
  { key: 'VISITOR', name: '访客', editable: false },
  { key: 'ADMIN', name: '管理员', editable: false },
  { key: 'OPERATOR', name: '操作员', editable: false }
]

const statusLabelMap: Record<MemberStatus, string> = {
  ACTIVE: '正常',
  PENDING: '待接受',
  DISABLED: '已禁用'
}

const statusClassMap: Record<MemberStatus, string> = {
  ACTIVE: 'bg-[#DCFCE7] text-[#166534]',
  PENDING: 'bg-[#FEF3C7] text-[#92400E]',
  DISABLED: 'bg-[#F3F4F6] text-[#52525B]'
}

const filteredMembers = computed(() => {
  const keyword = searchText.value.trim().toLowerCase()
  if (!keyword) return members.value
  return members.value.filter((item) => {
    return (
      item.name.toLowerCase().includes(keyword) ||
      item.email.toLowerCase().includes(keyword) ||
      item.team.toLowerCase().includes(keyword)
    )
  })
})

const statTotal = computed(() => members.value.length)
const statAdmins = computed(() => members.value.filter((item) => item.role === 'ADMIN').length)
const statPending = computed(() => members.value.filter((item) => item.status === 'PENDING').length)
const statDisabled = computed(() => members.value.filter((item) => item.status === 'DISABLED').length)
const roleOptions = computed(() => roleCatalog.value)

const roleLabelMap = computed<Record<string, string>>(() => {
  const map: Record<string, string> = {}
  for (const role of roleCatalog.value) {
    map[role.key] = role.name
  }
  return map
})

function initialsOf(name: string) {
  const trimmed = name.trim()
  if (!trimmed) return 'U'
  return trimmed.slice(0, 1).toUpperCase()
}

function openInviteDialog() {
  inviteForm.name = ''
  inviteForm.email = ''
  inviteForm.role = roleOptions.value[0]?.key || 'DEVELOPER'
  inviteForm.team = 'QA'
  isInviteDialogOpen.value = true
}

function closeInviteDialog() {
  isInviteDialogOpen.value = false
}

function submitInvite() {
  const name = inviteForm.name.trim()
  const email = inviteForm.email.trim()
  if (!name || !email) {
    window.alert('请填写姓名和邮箱')
    return
  }
  const item: MemberItem = {
    id: `m-${Date.now()}`,
    name,
    email,
    role: inviteForm.role,
    status: 'PENDING',
    team: inviteForm.team.trim() || 'QA',
    lastActiveAt: '-'
  }
  members.value = [item, ...members.value]
  closeInviteDialog()
}

function openRoleDialog(member: MemberItem) {
  editingMemberId.value = member.id
  roleForm.role = member.role
  roleForm.status = member.status
  isRoleDialogOpen.value = true
}

function closeRoleDialog() {
  isRoleDialogOpen.value = false
  editingMemberId.value = ''
}

function submitRole() {
  const targetId = editingMemberId.value
  if (!targetId) return
  members.value = members.value.map((item) =>
    item.id === targetId
      ? {
          ...item,
          role: roleForm.role,
          status: roleForm.status
        }
      : item
  )
  closeRoleDialog()
}

function deleteMember(item: MemberItem) {
  const confirmed = window.confirm(`确认移除成员「${item.name}」吗？`)
  if (!confirmed) return
  deletingId.value = item.id
  members.value = members.value.filter((row) => row.id !== item.id)
  deletingId.value = ''
}

function openRolePermissionsPage() {
  const pid = String(route.params.projectId || '').trim() || '1'
  void router.push(`/projects/${pid}/settings/roles`)
}

function loadRoleCatalog() {
  try {
    const raw = localStorage.getItem(roleStorageKey)
    if (!raw) {
      roleCatalog.value = [...fallbackRoles]
      return
    }
    const parsed = JSON.parse(raw)
    if (!Array.isArray(parsed)) {
      roleCatalog.value = [...fallbackRoles]
      return
    }
    const normalized: RoleCatalogItem[] = parsed
      .map((item) => ({
        key: String(item?.key || '').trim(),
        name: String(item?.name || '').trim(),
        editable: Boolean(item?.editable)
      }))
      .filter((item) => item.key && item.name)
    roleCatalog.value = normalized.length ? normalized : [...fallbackRoles]
  } catch {
    roleCatalog.value = [...fallbackRoles]
  }
}

onMounted(() => {
  loadRoleCatalog()
  const validKeys = new Set(roleCatalog.value.map((item) => item.key))
  members.value = members.value.map((item) => ({
    ...item,
    role: validKeys.has(item.role) ? item.role : roleCatalog.value[0]?.key || 'DEVELOPER'
  }))
})
</script>

<template>
  <div class="w-full bg-[rgba(236,236,240,0.3)] md:pr-[16.67px]">
    <div class="flex flex-col gap-[16px] px-[16px] pt-[16px] md:px-[24px] md:pt-[24px]">
      <div class="flex flex-col gap-[12px] md:flex-row md:items-center md:justify-between md:gap-0">
        <div class="flex flex-col gap-[2px]">
          <div class="text-[18px] font-semibold leading-[28px] text-[#0A0A0A]">成员权限</div>
          <div class="text-[14px] leading-[20px] text-[#717182]">管理项目成员、角色授权与访问状态</div>
        </div>
        <div class="flex items-center gap-[8px]">
          <button type="button" class="h-[32px] rounded-[10px] border border-black/10 bg-white px-[12px] text-[14px] font-medium leading-[20px] text-[#0A0A0A]" @click="openRolePermissionsPage">
            角色权限
          </button>
          <button type="button" class="h-[32px] rounded-[10px] bg-[#155DFC] px-[12px] text-[14px] font-medium leading-[20px] text-white" @click="openInviteDialog">
            邀请成员
          </button>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-[8px] md:grid-cols-4">
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">成员总数</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statTotal }}</div>
        </div>
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">管理角色</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statAdmins }}</div>
        </div>
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">待接受</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statPending }}</div>
        </div>
        <div class="rounded-[10px] border border-black/10 bg-white px-[12px] py-[10px]">
          <div class="text-[12px] leading-[16px] text-[#717182]">已禁用</div>
          <div class="mt-[4px] text-[20px] font-semibold leading-[28px] text-[#0A0A0A]">{{ statDisabled }}</div>
        </div>
      </div>

      <div class="relative h-[36px] w-full max-w-[420px] rounded-[10px] border border-black/10 bg-white px-[12px]">
        <input v-model="searchText" class="h-full w-full bg-transparent text-[14px] leading-[20px] text-[#0A0A0A] outline-none" placeholder="搜索成员姓名 / 邮箱 / 团队" type="text" />
      </div>

      <div class="overflow-hidden rounded-[14px] border border-black/10 bg-white">
        <div class="grid grid-cols-12 border-b border-black/10 bg-[#FAFAFA] px-[12px] py-[10px] text-[12px] leading-[16px] text-[#717182]">
          <div class="col-span-3">成员</div>
          <div class="col-span-2">团队</div>
          <div class="col-span-2">角色</div>
          <div class="col-span-2">状态</div>
          <div class="col-span-2">最近活跃</div>
          <div class="col-span-1 text-right">操作</div>
        </div>

        <div v-if="!filteredMembers.length" class="px-[12px] py-[24px] text-[13px] leading-[20px] text-[#717182]">暂无成员数据</div>

        <div v-for="item in filteredMembers" :key="item.id" class="grid grid-cols-12 items-center border-b border-black/5 px-[12px] py-[10px] last:border-b-0">
          <div class="col-span-3 min-w-0">
            <div class="flex items-center gap-[10px]">
              <div class="flex h-[28px] w-[28px] items-center justify-center rounded-full bg-[#DBEAFE] text-[12px] font-semibold leading-[16px] text-[#1D4ED8]">
                {{ initialsOf(item.name) }}
              </div>
              <div class="min-w-0">
                <div class="truncate text-[13px] font-medium leading-[18px] text-[#0A0A0A]" :title="item.name">{{ item.name }}</div>
                <div class="truncate text-[12px] leading-[16px] text-[#717182]" :title="item.email">{{ item.email }}</div>
              </div>
            </div>
          </div>
          <div class="col-span-2 truncate text-[13px] leading-[20px] text-[#52525B]" :title="item.team">{{ item.team }}</div>
          <div class="col-span-2 text-[13px] leading-[20px] text-[#0A0A0A]">{{ roleLabelMap[item.role] || item.role }}</div>
          <div class="col-span-2">
            <span class="inline-flex rounded-[999px] px-[8px] py-[2px] text-[12px] leading-[16px]" :class="statusClassMap[item.status]">
              {{ statusLabelMap[item.status] }}
            </span>
          </div>
          <div class="col-span-2 text-[12px] leading-[16px] text-[#717182]">{{ item.lastActiveAt }}</div>
          <div class="col-span-1 flex justify-end gap-[6px]">
            <button type="button" class="h-[28px] rounded-[8px] border border-black/10 px-[8px] text-[12px] leading-[18px] text-[#0A0A0A]" @click="openRoleDialog(item)">
              权限
            </button>
            <button
              type="button"
              class="h-[28px] rounded-[8px] border border-[#FCA5A5] px-[8px] text-[12px] leading-[18px] text-[#DC2626]"
              :disabled="deletingId === item.id"
              @click="deleteMember(item)"
            >
              {{ deletingId === item.id ? '删除中' : '移除' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div v-if="isInviteDialogOpen" class="fixed inset-0 z-50 flex items-center justify-center">
    <button class="absolute inset-0 bg-black/40" type="button" aria-label="Close" @click="closeInviteDialog" />
    <div class="relative w-full max-w-[calc(100vw-32px)] overflow-hidden rounded-[16px] border border-black/10 bg-white shadow-[0px_25px_50px_-12px_rgba(0,0,0,0.25)] sm:w-[560px] sm:max-w-[560px]">
      <div class="border-b border-black/10 px-[20px] py-[14px] text-[16px] font-semibold leading-[24px] text-[#0A0A0A]">邀请成员</div>
      <div class="grid grid-cols-1 gap-[12px] px-[20px] py-[16px] md:grid-cols-2">
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">姓名</div>
          <input v-model="inviteForm.name" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="text" placeholder="请输入姓名" />
        </div>
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">邮箱</div>
          <input v-model="inviteForm.email" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="email" placeholder="name@example.com" />
        </div>
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">角色</div>
          <select v-model="inviteForm.role" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none">
            <option v-for="role in roleOptions" :key="role.key" :value="role.key">{{ role.name }}</option>
          </select>
        </div>
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">团队</div>
          <input v-model="inviteForm.team" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="text" placeholder="如：QA / Platform" />
        </div>
      </div>
      <div class="flex items-center justify-end gap-[8px] border-t border-black/10 px-[20px] py-[12px]">
        <button type="button" class="h-[34px] rounded-[10px] border border-black/10 px-[12px] text-[13px] text-[#0A0A0A]" @click="closeInviteDialog">取消</button>
        <button type="button" class="h-[34px] rounded-[10px] bg-[#155DFC] px-[12px] text-[13px] text-white" @click="submitInvite">发送邀请</button>
      </div>
    </div>
  </div>

  <div v-if="isRoleDialogOpen" class="fixed inset-0 z-50 flex items-center justify-center">
    <button class="absolute inset-0 bg-black/40" type="button" aria-label="Close" @click="closeRoleDialog" />
    <div class="relative w-full max-w-[calc(100vw-32px)] overflow-hidden rounded-[16px] border border-black/10 bg-white shadow-[0px_25px_50px_-12px_rgba(0,0,0,0.25)] sm:w-[480px] sm:max-w-[480px]">
      <div class="border-b border-black/10 px-[20px] py-[14px] text-[16px] font-semibold leading-[24px] text-[#0A0A0A]">修改权限</div>
      <div class="grid grid-cols-1 gap-[12px] px-[20px] py-[16px]">
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">角色</div>
          <select v-model="roleForm.role" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none">
            <option v-for="role in roleOptions" :key="role.key" :value="role.key">{{ role.name }}</option>
          </select>
        </div>
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">状态</div>
          <select v-model="roleForm.status" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none">
            <option value="ACTIVE">正常</option>
            <option value="PENDING">待接受</option>
            <option value="DISABLED">已禁用</option>
          </select>
        </div>
      </div>
      <div class="flex items-center justify-end gap-[8px] border-t border-black/10 px-[20px] py-[12px]">
        <button type="button" class="h-[34px] rounded-[10px] border border-black/10 px-[12px] text-[13px] text-[#0A0A0A]" @click="closeRoleDialog">取消</button>
        <button type="button" class="h-[34px] rounded-[10px] bg-[#155DFC] px-[12px] text-[13px] text-white" @click="submitRole">保存</button>
      </div>
    </div>
  </div>
</template>
