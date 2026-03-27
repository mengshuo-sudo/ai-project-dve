<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute } from 'vue-router'

type PermissionGroup = {
  key: string
  label: string
  items: Array<{ key: string; label: string }>
}

type RoleCatalogItem = {
  key: string
  name: string
  editable: boolean
}

type RolePermission = {
  roleKey: string
  permissions: string[]
}

const route = useRoute()
const roleStorageKey = 'ai-testing-platform.role-catalog'
const rolePermissionStorageKey = 'ai-testing-platform.role-permissions'

const fallbackRoles: RoleCatalogItem[] = [
  { key: 'DEVELOPER', name: '开发者', editable: false },
  { key: 'VISITOR', name: '访客', editable: false },
  { key: 'ADMIN', name: '管理员', editable: false },
  { key: 'OPERATOR', name: '操作员', editable: false }
]

const permissionGroups: PermissionGroup[] = [
  {
    key: 'project',
    label: '项目配置',
    items: [
      { key: 'project.view', label: '查看项目' },
      { key: 'project.edit', label: '编辑项目' },
      { key: 'project.settings', label: '管理项目设置' }
    ]
  },
  {
    key: 'case',
    label: '测试资产',
    items: [
      { key: 'case.view', label: '查看用例/套件' },
      { key: 'case.edit', label: '编辑用例/套件' },
      { key: 'api.manage', label: '管理接口集合与测试数据' }
    ]
  },
  {
    key: 'run',
    label: '执行与报告',
    items: [
      { key: 'run.execute', label: '发起执行' },
      { key: 'run.manage', label: '停止/重跑执行' },
      { key: 'report.view', label: '查看报告与 Allure 报告' }
    ]
  },
  {
    key: 'member',
    label: '成员与权限',
    items: [
      { key: 'member.view', label: '查看成员' },
      { key: 'member.manage', label: '邀请/移除成员' },
      { key: 'role.manage', label: '管理角色与权限' }
    ]
  }
]

const defaultPermissionMap: Record<string, string[]> = {
  DEVELOPER: ['project.view', 'case.view', 'case.edit', 'api.manage', 'run.execute', 'report.view'],
  VISITOR: ['project.view', 'case.view', 'report.view'],
  ADMIN: [
    'project.view',
    'project.edit',
    'project.settings',
    'case.view',
    'case.edit',
    'api.manage',
    'run.execute',
    'run.manage',
    'report.view',
    'member.view',
    'member.manage',
    'role.manage'
  ],
  OPERATOR: ['project.view', 'case.view', 'run.execute', 'run.manage', 'report.view', 'member.view']
}

const roleCatalog = ref<RoleCatalogItem[]>([])
const rolePermissions = ref<RolePermission[]>([])
const selectedRoleKey = ref('')
const isCreateRoleDialogOpen = ref(false)

const createRoleForm = reactive({
  name: '',
  baseRoleKey: 'DEVELOPER'
})

const allPermissionItems = computed(() => permissionGroups.flatMap((group) => group.items))
const roleOptions = computed(() => roleCatalog.value)
const currentRole = computed(() => roleCatalog.value.find((item) => item.key === selectedRoleKey.value) || null)
const currentPermissionSet = computed(() => {
  const row = rolePermissions.value.find((item) => item.roleKey === selectedRoleKey.value)
  return new Set(row?.permissions || [])
})

function normalizeRoleKey(name: string) {
  const raw = name.trim()
  if (!raw) return ''
  return raw
    .replace(/\s+/g, '_')
    .replace(/[^\w\u4e00-\u9fa5]/g, '')
    .toUpperCase()
}

function readRoleCatalog() {
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

function persistRoleCatalog() {
  localStorage.setItem(roleStorageKey, JSON.stringify(roleCatalog.value))
}

function readRolePermissions() {
  try {
    const raw = localStorage.getItem(rolePermissionStorageKey)
    if (!raw) {
      rolePermissions.value = roleCatalog.value.map((role) => ({
        roleKey: role.key,
        permissions: [...(defaultPermissionMap[role.key] || [])]
      }))
      return
    }
    const parsed = JSON.parse(raw)
    if (!Array.isArray(parsed)) throw new Error('invalid data')
    rolePermissions.value = parsed
      .map((item) => ({
        roleKey: String(item?.roleKey || '').trim(),
        permissions: Array.isArray(item?.permissions)
          ? item.permissions.map((p: unknown) => String(p || '').trim()).filter(Boolean)
          : []
      }))
      .filter((item) => item.roleKey)
  } catch {
    rolePermissions.value = roleCatalog.value.map((role) => ({
      roleKey: role.key,
      permissions: [...(defaultPermissionMap[role.key] || [])]
    }))
  }
  ensureRolePermissionsIntegrity()
}

function ensureRolePermissionsIntegrity() {
  const byRole = new Map(rolePermissions.value.map((item) => [item.roleKey, item]))
  const next: RolePermission[] = []
  for (const role of roleCatalog.value) {
    const found = byRole.get(role.key)
    if (found) {
      next.push({ roleKey: role.key, permissions: [...new Set(found.permissions)] })
    } else {
      next.push({ roleKey: role.key, permissions: [...(defaultPermissionMap[role.key] || [])] })
    }
  }
  rolePermissions.value = next
}

function persistRolePermissions() {
  localStorage.setItem(rolePermissionStorageKey, JSON.stringify(rolePermissions.value))
}

function selectRole(roleKey: string) {
  selectedRoleKey.value = roleKey
}

function hasPermission(permissionKey: string) {
  return currentPermissionSet.value.has(permissionKey)
}

function togglePermission(permissionKey: string) {
  const roleKey = selectedRoleKey.value
  if (!roleKey) return
  const row = rolePermissions.value.find((item) => item.roleKey === roleKey)
  if (!row) return
  const next = new Set(row.permissions)
  if (next.has(permissionKey)) next.delete(permissionKey)
  else next.add(permissionKey)
  row.permissions = [...next]
}

function isGroupAllChecked(group: PermissionGroup) {
  return group.items.every((item) => currentPermissionSet.value.has(item.key))
}

function toggleGroup(group: PermissionGroup) {
  const roleKey = selectedRoleKey.value
  if (!roleKey) return
  const row = rolePermissions.value.find((item) => item.roleKey === roleKey)
  if (!row) return
  const next = new Set(row.permissions)
  const allChecked = group.items.every((item) => next.has(item.key))
  if (allChecked) {
    group.items.forEach((item) => next.delete(item.key))
  } else {
    group.items.forEach((item) => next.add(item.key))
  }
  row.permissions = [...next]
}

function savePermissions() {
  ensureRolePermissionsIntegrity()
  persistRolePermissions()
  window.alert('角色权限已保存')
}

function openCreateRoleDialog() {
  createRoleForm.name = ''
  createRoleForm.baseRoleKey = selectedRoleKey.value || 'DEVELOPER'
  isCreateRoleDialogOpen.value = true
}

function closeCreateRoleDialog() {
  isCreateRoleDialogOpen.value = false
}

function createCustomRole() {
  const name = createRoleForm.name.trim()
  if (!name) {
    window.alert('请输入角色名称')
    return
  }
  const key = normalizeRoleKey(name)
  if (!key) {
    window.alert('角色名称不合法')
    return
  }
  if (roleCatalog.value.some((item) => item.key === key)) {
    window.alert('角色已存在，请换一个名称')
    return
  }
  const baseRole = rolePermissions.value.find((item) => item.roleKey === createRoleForm.baseRoleKey)
  roleCatalog.value = [...roleCatalog.value, { key, name, editable: true }]
  rolePermissions.value = [
    ...rolePermissions.value,
    { roleKey: key, permissions: [...(baseRole?.permissions || [])] }
  ]
  persistRoleCatalog()
  persistRolePermissions()
  selectedRoleKey.value = key
  closeCreateRoleDialog()
}

function removeCurrentRole() {
  const role = currentRole.value
  if (!role || !role.editable) return
  const confirmed = window.confirm(`确认删除自定义角色「${role.name}」吗？`)
  if (!confirmed) return
  roleCatalog.value = roleCatalog.value.filter((item) => item.key !== role.key)
  rolePermissions.value = rolePermissions.value.filter((item) => item.roleKey !== role.key)
  persistRoleCatalog()
  persistRolePermissions()
  selectedRoleKey.value = roleCatalog.value[0]?.key || ''
}

onMounted(() => {
  readRoleCatalog()
  readRolePermissions()
  selectedRoleKey.value = roleCatalog.value[0]?.key || ''
})
</script>

<template>
  <div class="w-full bg-[rgba(236,236,240,0.3)] md:pr-[16.67px]">
    <div class="flex flex-col gap-[16px] px-[16px] pt-[16px] md:px-[24px] md:pt-[24px]">
      <div class="flex flex-col gap-[12px] md:flex-row md:items-center md:justify-between md:gap-0">
        <div class="flex flex-col gap-[2px]">
          <div class="text-[18px] font-semibold leading-[28px] text-[#0A0A0A]">角色权限</div>
          <div class="text-[14px] leading-[20px] text-[#717182]">
            projectId: {{ String(route.params.projectId || '-') }} · 管理开发者/访客/管理员/操作员及自定义角色权限
          </div>
        </div>
        <div class="flex items-center gap-[8px]">
          <button type="button" class="h-[32px] rounded-[10px] border border-black/10 bg-white px-[12px] text-[14px] font-medium leading-[20px] text-[#0A0A0A]" @click="openCreateRoleDialog">
            新建自定义角色
          </button>
          <button type="button" class="h-[32px] rounded-[10px] bg-[#155DFC] px-[12px] text-[14px] font-medium leading-[20px] text-white" @click="savePermissions">
            保存权限
          </button>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-[12px] lg:grid-cols-12">
        <div class="rounded-[14px] border border-black/10 bg-white lg:col-span-3">
          <div class="border-b border-black/10 px-[12px] py-[10px] text-[12px] leading-[16px] text-[#717182]">角色列表</div>
          <div class="flex flex-col gap-[6px] p-[10px]">
            <button
              v-for="role in roleOptions"
              :key="role.key"
              type="button"
              class="flex items-center justify-between rounded-[10px] border px-[10px] py-[8px] text-left transition-colors"
              :class="selectedRoleKey === role.key ? 'border-[#155DFC] bg-[#EFF6FF]' : 'border-black/10 bg-white hover:bg-[#FAFAFA]'"
              @click="selectRole(role.key)"
            >
              <span class="text-[13px] font-medium leading-[18px] text-[#0A0A0A]">{{ role.name }}</span>
              <span class="text-[11px] leading-[16px] text-[#717182]">{{ role.editable ? '自定义' : '内置' }}</span>
            </button>
          </div>
        </div>

        <div class="rounded-[14px] border border-black/10 bg-white lg:col-span-9">
          <div class="flex items-center justify-between border-b border-black/10 px-[12px] py-[10px]">
            <div class="text-[13px] leading-[18px] text-[#0A0A0A]">
              当前角色：
              <span class="font-semibold">{{ currentRole?.name || '-' }}</span>
            </div>
            <button
              v-if="currentRole?.editable"
              type="button"
              class="h-[28px] rounded-[8px] border border-[#FCA5A5] px-[10px] text-[12px] leading-[16px] text-[#DC2626]"
              @click="removeCurrentRole"
            >
              删除角色
            </button>
          </div>

          <div class="flex flex-col gap-[10px] p-[12px]">
            <div v-for="group in permissionGroups" :key="group.key" class="rounded-[10px] border border-black/10">
              <div class="flex items-center justify-between border-b border-black/10 bg-[#FAFAFA] px-[10px] py-[8px]">
                <div class="text-[13px] font-medium leading-[18px] text-[#0A0A0A]">{{ group.label }}</div>
                <button type="button" class="text-[12px] leading-[16px] text-[#155DFC]" @click="toggleGroup(group)">
                  {{ isGroupAllChecked(group) ? '取消全选' : '全选' }}
                </button>
              </div>
              <div class="grid grid-cols-1 gap-[6px] px-[10px] py-[8px] md:grid-cols-2">
                <label v-for="item in group.items" :key="item.key" class="flex items-center gap-[8px] rounded-[8px] px-[4px] py-[4px]">
                  <input :checked="hasPermission(item.key)" type="checkbox" @change="togglePermission(item.key)" />
                  <span class="text-[13px] leading-[18px] text-[#0A0A0A]">{{ item.label }}</span>
                </label>
              </div>
            </div>
            <div class="text-[12px] leading-[16px] text-[#717182]">
              当前角色共 {{ currentPermissionSet.size }} 项权限（总计 {{ allPermissionItems.length }} 项）
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div v-if="isCreateRoleDialogOpen" class="fixed inset-0 z-50 flex items-center justify-center">
    <button class="absolute inset-0 bg-black/40" type="button" aria-label="Close" @click="closeCreateRoleDialog" />
    <div class="relative w-full max-w-[calc(100vw-32px)] overflow-hidden rounded-[16px] border border-black/10 bg-white shadow-[0px_25px_50px_-12px_rgba(0,0,0,0.25)] sm:w-[520px] sm:max-w-[520px]">
      <div class="border-b border-black/10 px-[20px] py-[14px] text-[16px] font-semibold leading-[24px] text-[#0A0A0A]">新建自定义角色</div>
      <div class="grid grid-cols-1 gap-[12px] px-[20px] py-[16px]">
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">角色名称</div>
          <input v-model="createRoleForm.name" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none" type="text" placeholder="例如：审阅员" />
        </div>
        <div class="flex flex-col gap-[6px]">
          <div class="text-[13px] leading-[18px] text-[#0A0A0A]">复制权限自</div>
          <select v-model="createRoleForm.baseRoleKey" class="h-[36px] rounded-[10px] border border-black/10 px-[10px] text-[14px] outline-none">
            <option v-for="role in roleOptions" :key="role.key" :value="role.key">{{ role.name }}</option>
          </select>
        </div>
      </div>
      <div class="flex items-center justify-end gap-[8px] border-t border-black/10 px-[20px] py-[12px]">
        <button type="button" class="h-[34px] rounded-[10px] border border-black/10 px-[12px] text-[13px] text-[#0A0A0A]" @click="closeCreateRoleDialog">取消</button>
        <button type="button" class="h-[34px] rounded-[10px] bg-[#155DFC] px-[12px] text-[13px] text-white" @click="createCustomRole">创建</button>
      </div>
    </div>
  </div>
</template>
