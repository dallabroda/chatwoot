<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const emit = defineEmits(['updated']);

const SIX_DIGITS = /^\d{6}$/;

const { t } = useI18n();
const dialogRef = ref(null);
const inbox = ref(null);
const codeMethod = ref('SMS');
const code = ref('');
const pin = ref('');
const pendingAction = ref(null);
const confirmDeregister = ref(false);

const codeMethodOptions = [
  { value: 'SMS', label: t('PHONE_NUMBERS_PAGE.MANAGE.CODE_METHODS.SMS') },
  { value: 'VOICE', label: t('PHONE_NUMBERS_PAGE.MANAGE.CODE_METHODS.VOICE') },
];

const open = selectedInbox => {
  inbox.value = selectedInbox;
  code.value = '';
  pin.value = '';
  confirmDeregister.value = false;
  dialogRef.value.open();
};

// Runs one Meta call, shows its outcome and refreshes the number status
const run = async (action, request, successKey) => {
  pendingAction.value = action;
  try {
    await request();
    useAlert(t(`PHONE_NUMBERS_PAGE.MANAGE.${successKey}`));
    emit('updated', inbox.value);
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('PHONE_NUMBERS_PAGE.MANAGE.ERROR')
    );
  } finally {
    pendingAction.value = null;
  }
};

const requestCode = () =>
  run(
    'request_code',
    () =>
      InboxesAPI.requestWhatsappVerificationCode(
        inbox.value.id,
        codeMethod.value
      ),
    'CODE_SENT'
  );

const verifyCode = () =>
  run(
    'verify_code',
    () => InboxesAPI.verifyWhatsappCode(inbox.value.id, code.value),
    'VERIFIED'
  );

const register = () =>
  run(
    'register',
    () => InboxesAPI.registerWhatsappNumber(inbox.value.id, pin.value),
    'REGISTERED'
  );

const deregister = async () => {
  await run(
    'deregister',
    () => InboxesAPI.deregisterWhatsappNumber(inbox.value.id),
    'DEREGISTERED'
  );
  confirmDeregister.value = false;
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      $t('PHONE_NUMBERS_PAGE.MANAGE.TITLE', {
        number: inbox?.phone_number || '',
      })
    "
    :cancel-button-label="$t('PHONE_NUMBERS_PAGE.MANAGE.CLOSE')"
    :show-confirm-button="false"
    width="xl"
  >
    <div class="flex flex-col gap-6">
      <section class="flex flex-col gap-3">
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ $t('PHONE_NUMBERS_PAGE.MANAGE.VERIFY_TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ $t('PHONE_NUMBERS_PAGE.MANAGE.VERIFY_DESC') }}
        </p>
        <div class="flex flex-wrap items-center gap-2">
          <Select
            v-model="codeMethod"
            :options="codeMethodOptions"
            :aria-label="$t('PHONE_NUMBERS_PAGE.MANAGE.VERIFY_TITLE')"
          />
          <Button
            :label="$t('PHONE_NUMBERS_PAGE.MANAGE.SEND_CODE')"
            color="slate"
            size="sm"
            :is-loading="pendingAction === 'request_code'"
            :disabled="!!pendingAction"
            @click="requestCode"
          />
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <Input
            v-model="code"
            :placeholder="$t('PHONE_NUMBERS_PAGE.MANAGE.CODE_PLACEHOLDER')"
          />
          <Button
            :label="$t('PHONE_NUMBERS_PAGE.MANAGE.VERIFY')"
            size="sm"
            :is-loading="pendingAction === 'verify_code'"
            :disabled="!!pendingAction || !SIX_DIGITS.test(code)"
            @click="verifyCode"
          />
        </div>
      </section>

      <section class="flex flex-col gap-3">
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ $t('PHONE_NUMBERS_PAGE.MANAGE.REGISTER_TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ $t('PHONE_NUMBERS_PAGE.MANAGE.REGISTER_DESC') }}
        </p>
        <div class="flex flex-wrap items-center gap-2">
          <Input
            v-model="pin"
            type="password"
            :placeholder="$t('PHONE_NUMBERS_PAGE.MANAGE.PIN_PLACEHOLDER')"
          />
          <Button
            :label="$t('PHONE_NUMBERS_PAGE.MANAGE.REGISTER')"
            size="sm"
            :is-loading="pendingAction === 'register'"
            :disabled="!!pendingAction || !SIX_DIGITS.test(pin)"
            @click="register"
          />
        </div>
      </section>

      <section class="flex flex-col gap-3">
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ $t('PHONE_NUMBERS_PAGE.MANAGE.DEREGISTER_TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ $t('PHONE_NUMBERS_PAGE.MANAGE.DEREGISTER_DESC') }}
        </p>
        <div class="flex flex-wrap items-center gap-2">
          <Button
            v-if="!confirmDeregister"
            :label="$t('PHONE_NUMBERS_PAGE.MANAGE.DEREGISTER')"
            color="ruby"
            variant="faded"
            size="sm"
            :disabled="!!pendingAction"
            @click="confirmDeregister = true"
          />
          <template v-else>
            <Button
              :label="$t('PHONE_NUMBERS_PAGE.MANAGE.CONFIRM_DEREGISTER')"
              color="ruby"
              size="sm"
              :is-loading="pendingAction === 'deregister'"
              :disabled="!!pendingAction"
              @click="deregister"
            />
            <Button
              :label="$t('PHONE_NUMBERS_PAGE.MANAGE.CANCEL')"
              color="slate"
              variant="ghost"
              size="sm"
              @click="confirmDeregister = false"
            />
          </template>
        </div>
      </section>
    </div>
  </Dialog>
</template>
