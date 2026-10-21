<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  inboxes: {
    type: Array,
    required: true,
  },
});

const emit = defineEmits(['created']);

const CATEGORIES = ['MARKETING', 'UTILITY', 'AUTHENTICATION'];
const LANGUAGES = ['pt_BR', 'en_US', 'es'];
const BUTTON_TYPES = ['QUICK_REPLY', 'URL', 'PHONE_NUMBER'];
const MAX_BUTTONS = 10;
const NAME_PATTERN = /^[a-z0-9_]+$/;
const VARIABLE_PATTERN = /\{\{(\d+)\}\}/g;

const { t } = useI18n();
const dialogRef = ref(null);
const isSubmitting = ref(false);

const emptyForm = () => ({
  inboxId: props.inboxes[0] ? String(props.inboxes[0].id) : '',
  name: '',
  category: 'UTILITY',
  language: 'pt_BR',
  headerText: '',
  bodyText: '',
  bodyExamples: [],
  footerText: '',
  buttons: [],
});

const form = ref(emptyForm());

const inboxOptions = computed(() =>
  props.inboxes.map(inbox => ({ value: String(inbox.id), label: inbox.name }))
);
const categoryOptions = CATEGORIES.map(category => ({
  value: category,
  label: category,
}));
const languageOptions = LANGUAGES.map(language => ({
  value: language,
  label: language,
}));
const buttonTypeOptions = computed(() =>
  BUTTON_TYPES.map(type => ({
    value: type,
    label: t(`WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTON_TYPES.${type}`),
  }))
);

// Meta requires one example value per {{n}} variable in the body
const variableCount = computed(() => {
  const numbers = [...form.value.bodyText.matchAll(VARIABLE_PATTERN)].map(
    match => Number(match[1])
  );
  return numbers.length ? Math.max(...numbers) : 0;
});

watch(variableCount, count => {
  form.value.bodyExamples = Array.from(
    { length: count },
    (_, index) => form.value.bodyExamples[index] || ''
  );
});

const isNameValid = computed(() => NAME_PATTERN.test(form.value.name));

const isValid = computed(
  () =>
    form.value.inboxId &&
    isNameValid.value &&
    form.value.bodyText.trim() &&
    form.value.bodyExamples.every(example => example.trim()) &&
    form.value.buttons.every(button => button.text.trim())
);

const addButton = () => {
  form.value.buttons.push({
    type: 'QUICK_REPLY',
    text: '',
    url: '',
    phone_number: '',
  });
};

const removeButton = index => {
  form.value.buttons.splice(index, 1);
};

const open = () => {
  form.value = emptyForm();
  dialogRef.value.open();
};

const buildPayload = () => ({
  template: {
    name: form.value.name,
    category: form.value.category,
    language: form.value.language,
    header_text: form.value.headerText,
    body_text: form.value.bodyText,
    body_examples: form.value.bodyExamples,
    footer_text: form.value.footerText,
    buttons: form.value.buttons.map(({ type, text, url, phone_number }) => ({
      type,
      text,
      ...(type === 'URL' && { url }),
      ...(type === 'PHONE_NUMBER' && { phone_number }),
    })),
  },
});

const submit = async () => {
  if (!isValid.value || isSubmitting.value) return;
  isSubmitting.value = true;
  try {
    await InboxesAPI.createWhatsappTemplate(form.value.inboxId, buildPayload());
    useAlert(t('WHATSAPP_TEMPLATE_MGMT.CREATE.SUCCESS'));
    dialogRef.value.close();
    emit('created');
  } catch (error) {
    useAlert(
      parseAPIErrorResponse(error) || t('WHATSAPP_TEMPLATE_MGMT.CREATE.ERROR')
    );
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.TITLE')"
    :description="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.DESCRIPTION')"
    :confirm-button-label="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.SUBMIT')"
    :disable-confirm-button="!isValid"
    :is-loading="isSubmitting"
    width="2xl"
    overflow-y-auto
    @confirm="submit"
  >
    <div class="flex flex-col gap-4">
      <div class="flex flex-wrap gap-3">
        <div class="flex flex-col gap-1">
          <span class="text-sm text-n-slate-11">
            {{ $t('WHATSAPP_TEMPLATE_MGMT.CREATE.INBOX') }}
          </span>
          <Select
            v-model="form.inboxId"
            :options="inboxOptions"
            :aria-label="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.INBOX')"
          />
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-sm text-n-slate-11">
            {{ $t('WHATSAPP_TEMPLATE_MGMT.CREATE.CATEGORY') }}
          </span>
          <Select
            v-model="form.category"
            :options="categoryOptions"
            :aria-label="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.CATEGORY')"
          />
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-sm text-n-slate-11">
            {{ $t('WHATSAPP_TEMPLATE_MGMT.CREATE.LANGUAGE') }}
          </span>
          <Select
            v-model="form.language"
            :options="languageOptions"
            :aria-label="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.LANGUAGE')"
          />
        </div>
      </div>

      <Input
        v-model="form.name"
        :label="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.NAME')"
        :placeholder="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.NAME_PLACEHOLDER')"
        :message="
          form.name && !isNameValid
            ? $t('WHATSAPP_TEMPLATE_MGMT.CREATE.NAME_ERROR')
            : ''
        "
        :message-type="form.name && !isNameValid ? 'error' : 'info'"
      />

      <Input
        v-model="form.headerText"
        :label="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.HEADER')"
        :placeholder="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.OPTIONAL')"
      />

      <TextArea
        v-model="form.bodyText"
        :label="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.BODY')"
        :placeholder="
          $t('WHATSAPP_TEMPLATE_MGMT.CREATE.BODY_PLACEHOLDER', {
            first: '{{1}}',
            second: '{{2}}',
          })
        "
        :max-length="1024"
        show-character-count
        auto-height
      />

      <div v-if="form.bodyExamples.length" class="flex flex-col gap-2">
        <span class="text-sm text-n-slate-11">
          {{ $t('WHATSAPP_TEMPLATE_MGMT.CREATE.EXAMPLES') }}
        </span>
        <Input
          v-for="(_, index) in form.bodyExamples"
          :key="index"
          v-model="form.bodyExamples[index]"
          :placeholder="`{{${index + 1}}}`"
        />
      </div>

      <Input
        v-model="form.footerText"
        :label="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.FOOTER')"
        :placeholder="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.OPTIONAL')"
      />

      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between">
          <span class="text-sm text-n-slate-11">
            {{ $t('WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS') }}
          </span>
          <Button
            :label="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.ADD_BUTTON')"
            icon="i-lucide-plus"
            color="slate"
            size="sm"
            :disabled="form.buttons.length >= MAX_BUTTONS"
            @click="addButton"
          />
        </div>
        <div
          v-for="(button, index) in form.buttons"
          :key="index"
          class="flex flex-wrap items-center gap-2"
        >
          <Select
            v-model="button.type"
            :options="buttonTypeOptions"
            :aria-label="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTONS')"
          />
          <Input
            v-model="button.text"
            :placeholder="$t('WHATSAPP_TEMPLATE_MGMT.CREATE.BUTTON_TEXT')"
          />
          <Input
            v-if="button.type === 'URL'"
            v-model="button.url"
            placeholder="https://"
          />
          <Input
            v-if="button.type === 'PHONE_NUMBER'"
            v-model="button.phone_number"
            placeholder="+5511999999999"
          />
          <Button
            icon="i-lucide-trash-2"
            color="ruby"
            variant="ghost"
            size="sm"
            @click="removeButton(index)"
          />
        </div>
      </div>
    </div>
  </Dialog>
</template>
