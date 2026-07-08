import { defineStore } from 'pinia'
import { ref } from 'vue'

function readStoredRole() {
  const storedRole = localStorage.getItem('zhiyu_role')
  if (storedRole !== '0' && storedRole !== '1') return null
  return Number(storedRole)
}

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('zhiyu_token') || '')
  const username = ref(localStorage.getItem('zhiyu_username') || '')
  const role = ref<number | null>(readStoredRole())

  function setLogin(t: string, u: string, r: number) {
    if (r !== 0 && r !== 1) return

    token.value = t
    username.value = u
    role.value = r
    localStorage.setItem('zhiyu_token', t)
    localStorage.setItem('zhiyu_username', u)
    localStorage.setItem('zhiyu_role', String(r))
  }

  function logout() {
    token.value = ''
    username.value = ''
    role.value = null
    localStorage.removeItem('zhiyu_token')
    localStorage.removeItem('zhiyu_username')
    localStorage.removeItem('zhiyu_role')
  }

  return { token, username, role, setLogin, logout }
})
