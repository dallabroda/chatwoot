<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';

defineProps({
  isCollapsed: { type: Boolean, default: false },
});

const SUPPORT_WHATSAPP_NUMBER = '554888692538';

const { t } = useI18n();
const currentUser = useMapGetter('getCurrentUser');
const { accountId, currentAccount } = useAccount();

const supportUrl = computed(() => {
  const text = t('SIDEBAR.SUPPORT_MESSAGE', {
    name: currentUser.value?.name || '',
    email: currentUser.value?.email || '',
    account: currentAccount.value?.name || '',
    id: accountId.value || '',
  });
  return `https://wa.me/${SUPPORT_WHATSAPP_NUMBER}?text=${encodeURIComponent(text)}`;
});
</script>

<template>
  <a
    :href="supportUrl"
    target="_blank"
    rel="noopener noreferrer"
    :title="t('SIDEBAR.SUPPORT')"
    class="flex items-center gap-2 w-full px-2 py-1.5 rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
    :class="isCollapsed ? 'justify-center' : 'justify-start'"
  >
    <span class="i-woot-whatsapp size-4 text-n-teal-10 flex-shrink-0" />
    <span v-if="!isCollapsed" class="text-sm truncate">
      {{ t('SIDEBAR.SUPPORT') }}
    </span>
  </a>
</template>
