<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import WhatsappEvolutionConnectionsAPI from 'dashboard/api/whatsappEvolutionConnections';
import Input from 'dashboard/components-next/input/Input.vue';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const router = useRouter();
const { t } = useI18n();
const store = useStore();

const step = ref('form'); // form -> connecting -> qr -> connected
const inboxName = ref('');
const riskAccepted = ref(false);
const isSubmitting = ref(false);
const errorMessage = ref('');
const qrCode = ref('');
const inboxId = ref(null);
let pollTimer = null;

const stopPolling = () => {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
};

const onQrUpdated = payload => {
  if (!inboxId.value || payload.inbox_id !== inboxId.value) return;

  if (payload.qr_code) {
    qrCode.value = payload.qr_code;
    step.value = 'qr';
  }

  if (payload.connection_state === 'connected') {
    stopPolling();
    step.value = 'connected';
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.CONNECTED'));
    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: inboxId.value },
    });
  }
};

const pollConnectionStatus = async () => {
  if (!inboxId.value || step.value === 'connected') {
    stopPolling();
    return;
  }
  try {
    await store.dispatch('inboxes/get');
    const inboxes = store.getters['inboxes/getInboxes'];
    const currentInbox = inboxes.find(i => i.id === inboxId.value);
    if (currentInbox?.additional_attributes?.connection_state === 'connected') {
      stopPolling();
      onQrUpdated({ inbox_id: inboxId.value, connection_state: 'connected' });
    }
  } catch {
    // silent
  }
};

const canSubmit = () => inboxName.value.trim() && riskAccepted.value;

onMounted(() => {
  emitter.on(BUS_EVENTS.WHATSAPP_QR_UPDATED, onQrUpdated);
});

onBeforeUnmount(() => {
  stopPolling();
  emitter.off(BUS_EVENTS.WHATSAPP_QR_UPDATED, onQrUpdated);
});

const connect = async () => {
  if (!canSubmit() || isSubmitting.value) return;

  isSubmitting.value = true;
  errorMessage.value = '';
  step.value = 'connecting';

  try {
    const { data } = await WhatsappEvolutionConnectionsAPI.create({
      name: inboxName.value.trim(),
      risk_accepted: true,
    });
    inboxId.value = data.id;
    qrCode.value = data.qr_code;
    step.value = 'qr';
    stopPolling();
    pollTimer = setInterval(pollConnectionStatus, 3000);
  } catch (error) {
    stopPolling();
    errorMessage.value =
      error?.response?.data?.error ||
      t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.ERROR');
    step.value = 'form';
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col gap-5 max-w-lg">
    <template v-if="step === 'form'">
      <Input
        v-model="inboxName"
        :label="t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.NAME_LABEL')"
        :placeholder="
          t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.NAME_PLACEHOLDER')
        "
      />

      <Banner color="ruby">
        <p class="font-semibold mb-1">
          {{ t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.RISK_TITLE') }}
        </p>
        <p>{{ t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.RISK_BODY') }}</p>
      </Banner>

      <label class="flex items-start gap-2 cursor-pointer select-none">
        <Checkbox v-model="riskAccepted" class="mt-0.5" />
        <span class="text-sm text-n-slate-11">
          {{ t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.RISK_CHECKBOX') }}
        </span>
      </label>

      <p v-if="errorMessage" class="text-sm text-n-ruby-11">
        {{ errorMessage }}
      </p>

      <Button
        :label="t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.CONNECT_BUTTON')"
        :disabled="!canSubmit() || isSubmitting"
        :is-loading="isSubmitting"
        class="self-start"
        @click="connect"
      />
    </template>

    <template v-else-if="step === 'connecting'">
      <div class="flex items-center gap-3 text-n-slate-11">
        <Spinner />
        <span>{{ t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.CONNECTING') }}</span>
      </div>
    </template>

    <template v-else-if="step === 'qr'">
      <p class="text-sm text-n-slate-11">
        {{ t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.SCAN_INSTRUCTIONS') }}
      </p>
      <img
        v-if="qrCode"
        :src="qrCode"
        :alt="t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.NAME_LABEL')"
        class="w-56 h-56 border border-n-weak rounded-lg self-center"
      />
      <div class="flex items-center gap-2 text-sm text-n-slate-11">
        <Spinner />
        <span>{{
          t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.WAITING_FOR_SCAN')
        }}</span>
      </div>
    </template>

    <template v-else-if="step === 'connected'">
      <p class="text-sm text-n-teal-11">
        {{ t('INBOX_MGMT.ADD.WHATSAPP.QR_UNOFFICIAL.CONNECTED') }}
      </p>
    </template>
  </div>
</template>
