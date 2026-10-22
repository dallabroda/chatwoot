<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import WhatsappEvolutionConnectionsAPI from 'dashboard/api/whatsappEvolutionConnections';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  inboxId: { type: Number, required: true },
});

const { t } = useI18n();
const store = useStore();
const dialogRef = ref(null);
const isLoading = ref(false);
const qrCode = ref('');
const errorMessage = ref('');
let pollTimer = null;

const stopPolling = () => {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
};

const finish = () => {
  stopPolling();
  store.dispatch('inboxes/get');
  useAlert(t('INBOX_MGMT.QR_CONNECTION.CONNECTED_SUCCESS'));
  dialogRef.value?.close();
};

const pollStatus = async () => {
  try {
    const { data } = await WhatsappEvolutionConnectionsAPI.status(
      props.inboxId
    );
    if (data.connection_state === 'connected') finish();
  } catch {
    // keep polling; a transient error must not close the dialog
  }
};

const onQrUpdated = payload => {
  if (payload.inbox_id !== props.inboxId) return;
  if (payload.qr_code) qrCode.value = payload.qr_code;
  if (payload.connection_state === 'connected') finish();
};

const open = async () => {
  qrCode.value = '';
  errorMessage.value = '';
  isLoading.value = true;
  dialogRef.value?.open();
  try {
    const { data } = await WhatsappEvolutionConnectionsAPI.qr(props.inboxId);
    if (data.connection_state === 'connected') {
      finish();
      return;
    }
    qrCode.value = data.qr_code;
    stopPolling();
    pollTimer = setInterval(pollStatus, 3000);
  } catch (error) {
    errorMessage.value =
      error?.response?.data?.error || t('INBOX_MGMT.QR_CONNECTION.ERROR');
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => emitter.on(BUS_EVENTS.WHATSAPP_QR_UPDATED, onQrUpdated));
onBeforeUnmount(() => {
  stopPolling();
  emitter.off(BUS_EVENTS.WHATSAPP_QR_UPDATED, onQrUpdated);
});

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('INBOX_MGMT.QR_CONNECTION.DIALOG_TITLE')"
    :description="t('INBOX_MGMT.QR_CONNECTION.SCAN_INSTRUCTIONS')"
    :show-confirm-button="false"
    :cancel-button-label="t('INBOX_MGMT.QR_CONNECTION.CLOSE')"
    width="md"
    @close="stopPolling"
  >
    <div class="flex flex-col items-center gap-4 py-2">
      <Spinner v-if="isLoading" />
      <p v-else-if="errorMessage" class="text-sm text-n-ruby-11">
        {{ errorMessage }}
      </p>
      <template v-else-if="qrCode">
        <img
          :src="qrCode"
          :alt="t('INBOX_MGMT.QR_CONNECTION.DIALOG_TITLE')"
          class="w-56 h-56 border border-n-weak rounded-lg"
        />
        <div class="flex items-center gap-2 text-sm text-n-slate-11">
          <Spinner />
          <span>{{ t('INBOX_MGMT.QR_CONNECTION.WAITING_FOR_SCAN') }}</span>
        </div>
      </template>
    </div>
  </Dialog>
</template>
