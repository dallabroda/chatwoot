<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import WhatsappSharedAssetsAPI from 'dashboard/api/whatsappSharedAssets';
import { metaAssetLabels } from '../constants';

import Label from 'dashboard/components-next/label/Label.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const route = useRoute();

const assetsByType = ref(null);
const isLoading = ref(true);

const assetType = computed(() => route.meta.assetType);
const title = computed(() => metaAssetLabels(t)[assetType.value]);
const assets = computed(() => assetsByType.value?.[assetType.value] || []);

const fetchAssets = async () => {
  if (assetsByType.value) return;
  try {
    const { data } = await WhatsappSharedAssetsAPI.get();
    assetsByType.value = data.payload;
  } catch {
    useAlert(t('META_ASSETS_PAGE.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

watch(assetType, fetchAssets, { immediate: true });
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="flex flex-col gap-1 px-6 pt-6 pb-4 border-b border-n-weak">
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ title }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('META_ASSETS_PAGE.DESCRIPTION') }}
      </p>
    </header>

    <main class="flex-1 px-6 py-4 overflow-y-auto">
      <div v-if="isLoading" class="flex items-center justify-center py-16">
        <Spinner :size="24" />
      </div>
      <div
        v-else-if="!assets.length"
        class="flex items-center justify-center py-16"
      >
        <span class="text-base text-n-slate-11">
          {{ t('META_ASSETS_PAGE.EMPTY_STATE') }}
        </span>
      </div>
      <ul v-else class="flex flex-col gap-2">
        <li
          v-for="asset in assets"
          :key="`${asset.phone_number}-${asset.id}`"
          class="flex flex-wrap items-center justify-between gap-3 p-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
        >
          <div class="flex flex-col min-w-0 gap-1">
            <span class="text-sm font-medium truncate text-n-slate-12">
              {{ asset.name || asset.id }}
            </span>
            <span class="text-xs text-n-slate-10">
              {{ t('META_ASSETS_PAGE.ID', { id: asset.id }) }}
            </span>
          </div>
          <div class="flex flex-wrap items-center gap-2">
            <Label
              v-if="asset.error"
              :label="t('META_ASSETS_PAGE.UNAVAILABLE')"
              color="amber"
              compact
            />
            <Label
              :label="
                t('META_ASSETS_PAGE.SHARED_WITH', {
                  number: asset.phone_number,
                })
              "
              compact
            />
          </div>
        </li>
      </ul>
    </main>
  </section>
</template>
