<script setup>
import { computed, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import InboxHealthAPI from 'dashboard/api/inboxHealth';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ManageNumberDialog from '../components/ManageNumberDialog.vue';

const QUALITY_COLORS = { GREEN: 'teal', YELLOW: 'amber', RED: 'ruby' };
const CONNECTED_STATUS = 'CONNECTED';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const inboxes = useMapGetter('inboxes/getInboxes');
const isLoading = ref(true);
const healthByInbox = ref({});
const manageDialogRef = ref(null);

const isEvolutionQr = inbox =>
  inbox.additional_attributes?.connection_type === 'evolution_qr';

const whatsappInboxes = computed(() =>
  inboxes.value.filter(
    inbox => inbox.channel_type === INBOX_TYPES.WHATSAPP || isEvolutionQr(inbox)
  )
);

// Health comes from the Cloud API; other WhatsApp providers have no equivalent
const fetchHealth = async inbox => {
  if (inbox.provider !== 'whatsapp_cloud') return;
  try {
    const { data } = await InboxHealthAPI.getHealthStatus(inbox.id);
    healthByInbox.value = { ...healthByInbox.value, [inbox.id]: data };
  } catch {
    healthByInbox.value = {
      ...healthByInbox.value,
      [inbox.id]: { unavailable: true },
    };
  }
};

const qualityColor = health => QUALITY_COLORS[health.quality_rating] || 'slate';

const addNumber = () => {
  router.push({
    name: 'settings_inboxes_page_channel',
    params: { sub_page: 'whatsapp' },
  });
};

const openConversations = inbox => {
  router.push({ name: 'inbox_dashboard', params: { inbox_id: inbox.id } });
};

const openSettings = inbox => {
  router.push({ name: 'settings_inbox_show', params: { inboxId: inbox.id } });
};

onMounted(async () => {
  try {
    await store.dispatch('inboxes/get');
    await Promise.all(whatsappInboxes.value.map(fetchHealth));
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header
      class="flex items-center justify-between gap-4 px-6 pt-6 pb-4 border-b border-n-weak shrink-0"
    >
      <div class="flex flex-col gap-1">
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('PHONE_NUMBERS_PAGE.HEADER') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ t('PHONE_NUMBERS_PAGE.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <Button
          icon="i-lucide-webhook"
          :label="t('PHONE_NUMBERS_PAGE.WEBHOOKS')"
          color="slate"
          @click="router.push({ name: 'phone_numbers_webhooks' })"
        />
        <Button
          icon="i-lucide-plus"
          :label="t('PHONE_NUMBERS_PAGE.ADD_NUMBER')"
          @click="addNumber"
        />
      </div>
    </header>

    <main class="flex-1 px-6 py-4 overflow-y-auto">
      <div v-if="isLoading" class="flex items-center justify-center py-16">
        <Spinner :size="24" />
      </div>

      <div
        v-else-if="!whatsappInboxes.length"
        class="flex flex-col items-center justify-center gap-4 py-16"
      >
        <Icon icon="i-woot-whatsapp" class="size-8 text-n-slate-10" />
        <span class="text-base text-n-slate-11">
          {{ t('PHONE_NUMBERS_PAGE.EMPTY_STATE') }}
        </span>
        <Button
          icon="i-lucide-plus"
          :label="t('PHONE_NUMBERS_PAGE.ADD_NUMBER')"
          @click="addNumber"
        />
      </div>

      <ul v-else class="flex flex-col gap-3">
        <li
          v-for="inbox in whatsappInboxes"
          :key="inbox.id"
          class="flex flex-wrap items-center justify-between gap-4 p-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
        >
          <div class="flex items-center gap-3 min-w-0">
            <div
              class="flex items-center justify-center rounded-full size-10 bg-n-alpha-2 shrink-0"
            >
              <Icon icon="i-woot-whatsapp" class="size-5 text-n-slate-10" />
            </div>
            <div class="flex flex-col min-w-0 gap-1">
              <span class="text-sm font-medium truncate text-n-slate-12">
                {{ inbox.phone_number || inbox.name }}
              </span>
              <span
                v-if="
                  inbox.phone_number &&
                  (healthByInbox[inbox.id]?.verified_name || inbox.name)
                "
                class="text-sm truncate text-n-slate-11"
              >
                {{ healthByInbox[inbox.id]?.verified_name || inbox.name }}
              </span>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <Label
              v-if="isEvolutionQr(inbox)"
              :label="t('PHONE_NUMBERS_PAGE.UNOFFICIAL')"
              color="ruby"
              compact
            />
            <Label
              v-if="
                isEvolutionQr(inbox) &&
                inbox.additional_attributes?.connection_state
              "
              :label="
                inbox.additional_attributes.connection_state === 'connected'
                  ? t('PHONE_NUMBERS_PAGE.STATUS.CONNECTED')
                  : inbox.additional_attributes.connection_state
              "
              :color="
                inbox.additional_attributes.connection_state === 'connected'
                  ? 'teal'
                  : 'amber'
              "
              compact
            />
            <template v-if="healthByInbox[inbox.id]?.unavailable">
              <Label
                :label="t('PHONE_NUMBERS_PAGE.HEALTH_UNAVAILABLE')"
                color="amber"
                compact
              />
            </template>
            <template v-else-if="healthByInbox[inbox.id]">
              <Label
                :label="
                  healthByInbox[inbox.id].status === CONNECTED_STATUS
                    ? t('PHONE_NUMBERS_PAGE.STATUS.CONNECTED')
                    : healthByInbox[inbox.id].status
                "
                :color="
                  healthByInbox[inbox.id].status === CONNECTED_STATUS
                    ? 'teal'
                    : 'amber'
                "
                compact
              />
              <Label
                v-if="healthByInbox[inbox.id].quality_rating"
                :label="
                  t('PHONE_NUMBERS_PAGE.QUALITY', {
                    rating: healthByInbox[inbox.id].quality_rating,
                  })
                "
                :color="qualityColor(healthByInbox[inbox.id])"
                compact
              />
              <Label
                v-if="healthByInbox[inbox.id].messaging_limit_tier"
                :label="healthByInbox[inbox.id].messaging_limit_tier"
                compact
              />
              <Label
                v-if="healthByInbox[inbox.id].is_on_biz_app"
                :label="t('PHONE_NUMBERS_PAGE.COEXISTENCE')"
                color="blue"
                compact
              />
            </template>
            <Label
              v-if="inbox.reauthorization_required"
              :label="t('PHONE_NUMBERS_PAGE.REAUTHORIZATION_REQUIRED')"
              color="ruby"
              compact
            />
          </div>

          <div class="flex items-center gap-2">
            <Button
              :label="t('PHONE_NUMBERS_PAGE.OPEN_CONVERSATIONS')"
              faded
              slate
              size="sm"
              @click="openConversations(inbox)"
            />
            <Button
              v-if="inbox.provider === 'whatsapp_cloud'"
              :label="t('PHONE_NUMBERS_PAGE.MANAGE_NUMBER')"
              faded
              slate
              size="sm"
              @click="manageDialogRef.open(inbox)"
            />
            <Button
              :label="t('PHONE_NUMBERS_PAGE.SETTINGS')"
              faded
              slate
              size="sm"
              @click="openSettings(inbox)"
            />
          </div>
        </li>
      </ul>
    </main>
    <ManageNumberDialog ref="manageDialogRef" @updated="fetchHealth" />
  </section>
</template>
