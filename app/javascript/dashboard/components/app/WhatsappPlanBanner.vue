<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useEventListener } from '@vueuse/core';
import { useAdmin } from 'dashboard/composables/useAdmin';
import CustomBillingAPI from 'dashboard/api/customBilling';
import Banner from 'dashboard/components-next/banner/Banner.vue';

const route = useRoute();
const router = useRouter();
const { t, locale } = useI18n();
const { isAdmin } = useAdmin();

const summary = ref(null);

const fetchSummary = async () => {
  if (!isAdmin.value || !route.params.accountId) return;
  try {
    const { data } = await CustomBillingAPI.getSummary();
    summary.value = data;
  } catch {
    summary.value = null;
  }
};

watch([() => route.params.accountId, isAdmin], fetchSummary, {
  immediate: true,
});
useEventListener(window, 'focus', fetchSummary);

const pausedCount = computed(
  () => summary.value?.paused_inbox_ids?.length || 0
);
const inTrial = computed(() => Boolean(summary.value?.in_trial));
const inCourtesy = computed(() => Boolean(summary.value?.in_courtesy));

const formatDate = value =>
  new Date(value).toLocaleDateString(locale.value.replace('_', '-'));

const message = computed(() => {
  if (pausedCount.value) {
    return t('GENERAL_SETTINGS.WHATSAPP_PLAN_BANNER.PAUSED', {
      count: pausedCount.value,
    });
  }
  if (inCourtesy.value) {
    return t('GENERAL_SETTINGS.WHATSAPP_PLAN_BANNER.COURTESY', {
      limit: summary.value.effective_waba_limit,
      date: formatDate(summary.value.courtesy_until),
    });
  }
  return t('GENERAL_SETTINGS.WHATSAPP_PLAN_BANNER.TRIAL', {
    limit: summary.value.effective_waba_limit,
    date: formatDate(summary.value.trial_ends_at),
  });
});

const openBilling = () => {
  router.push({
    name: 'billing_settings_index',
    params: { accountId: route.params.accountId },
  });
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <Banner
    v-if="pausedCount || inCourtesy || inTrial"
    :color="pausedCount ? 'ruby' : 'amber'"
    role="alert"
    class="!rounded-none !justify-center flex-wrap shrink-0"
    :action-label="t('GENERAL_SETTINGS.WHATSAPP_PLAN_BANNER.OPEN_PLANS')"
    @action="openBilling"
  >
    {{ message }}
  </Banner>
</template>
