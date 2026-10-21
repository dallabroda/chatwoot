<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import WhatsappWebhookEventsAPI from 'dashboard/api/whatsappWebhookEvents';

import Button from 'dashboard/components-next/button/Button.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const REFRESH_INTERVAL_MS = 5000;

const { t } = useI18n();
const router = useRouter();

const events = ref([]);
const isLoading = ref(true);
const autoRefresh = ref(true);
const expandedIndex = ref(null);
let refreshTimer = null;

const changesOf = event =>
  (event.payload.entry || []).flatMap(entry => entry.changes || []);

const fieldsOf = event => [
  ...new Set(changesOf(event).map(change => change.field)),
];

const phoneOf = event =>
  changesOf(event).find(change => change.value?.metadata)?.value.metadata
    .display_phone_number;

const fetchEvents = async () => {
  try {
    const { data } = await WhatsappWebhookEventsAPI.get();
    events.value = data.payload;
  } catch {
    useAlert(t('WEBHOOK_EVENTS_PAGE.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const toggleEvent = index => {
  expandedIndex.value = expandedIndex.value === index ? null : index;
};

onMounted(() => {
  fetchEvents();
  refreshTimer = setInterval(() => {
    if (autoRefresh.value) fetchEvents();
  }, REFRESH_INTERVAL_MS);
});

onBeforeUnmount(() => clearInterval(refreshTimer));
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header
      class="flex flex-wrap items-center justify-between gap-4 px-6 pt-6 pb-4 border-b border-n-weak shrink-0"
    >
      <div class="flex flex-col gap-1">
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('WEBHOOK_EVENTS_PAGE.HEADER') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ t('WEBHOOK_EVENTS_PAGE.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex items-center gap-3">
        <label class="flex items-center gap-2 text-sm text-n-slate-11">
          <Switch v-model="autoRefresh" />
          {{ t('WEBHOOK_EVENTS_PAGE.AUTO_REFRESH') }}
        </label>
        <Button
          :label="t('WEBHOOK_EVENTS_PAGE.BACK')"
          icon="i-lucide-arrow-left"
          color="slate"
          size="sm"
          @click="router.push({ name: 'phone_numbers_index' })"
        />
      </div>
    </header>

    <main class="flex-1 px-6 py-4 overflow-y-auto">
      <div v-if="isLoading" class="flex items-center justify-center py-16">
        <Spinner :size="24" />
      </div>
      <div
        v-else-if="!events.length"
        class="flex items-center justify-center py-16"
      >
        <span class="text-base text-n-slate-11">
          {{ t('WEBHOOK_EVENTS_PAGE.EMPTY_STATE') }}
        </span>
      </div>
      <ul v-else class="flex flex-col gap-2">
        <li
          v-for="(event, index) in events"
          :key="`${event.received_at}-${index}`"
          class="rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
        >
          <button
            type="button"
            class="flex flex-wrap items-center justify-between w-full gap-3 p-3 text-start"
            @click="toggleEvent(index)"
          >
            <div class="flex flex-wrap items-center gap-2">
              <Label
                v-for="field in fieldsOf(event)"
                :key="field"
                :label="field"
                color="blue"
                compact
              />
              <span v-if="phoneOf(event)" class="text-sm text-n-slate-11">
                {{ phoneOf(event) }}
              </span>
            </div>
            <span class="text-xs text-n-slate-10">
              {{ new Date(event.received_at).toLocaleString() }}
            </span>
          </button>
          <pre
            v-if="expandedIndex === index"
            class="p-3 m-0 overflow-x-auto text-xs border-t border-n-weak text-n-slate-12"
            >{{ JSON.stringify(event.payload, null, 2) }}</pre
          >
        </li>
      </ul>
    </main>
  </section>
</template>
