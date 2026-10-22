<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Label from 'dashboard/components-next/label/Label.vue';

const props = defineProps({
  inbox: { type: Object, required: true },
});

const { t } = useI18n();

const state = computed(
  () => props.inbox.additional_attributes?.connection_state
);

const label = computed(() => {
  if (state.value === 'connected') {
    return t('INBOX_MGMT.QR_CONNECTION.STATUS.CONNECTED');
  }
  if (state.value === 'qr_pending') {
    return t('INBOX_MGMT.QR_CONNECTION.STATUS.QR_PENDING');
  }
  return t('INBOX_MGMT.QR_CONNECTION.STATUS.DISCONNECTED');
});

const color = computed(() => {
  if (state.value === 'connected') return 'teal';
  if (state.value === 'qr_pending') return 'amber';
  return 'ruby';
});
</script>

<template>
  <Label :label="label" :color="color" compact />
</template>
