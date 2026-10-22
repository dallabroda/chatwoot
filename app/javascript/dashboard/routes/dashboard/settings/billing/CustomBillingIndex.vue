<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CustomBillingAPI from 'dashboard/api/customBilling';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const PRICE_PER_NUMBER_CENTS = 6000;
const MAX_NUMBERS = 50;
const PRICE_TABLE = [1, 2, 3, 4];

const { t, locale } = useI18n();

const loading = ref(true);
const submitting = ref(false);
const summary = ref({});
const invoices = ref([]);
const selectedNumbers = ref(1);
const dialogRef = ref(null);
const dialogMode = ref('subscribe');

const emptyForm = () => ({
  holder_name: '',
  number: '',
  expiry_month: '',
  expiry_year: '',
  ccv: '',
  cpf_cnpj: '',
  phone: '',
  postal_code: '',
  province: '',
  address: '',
  address_number: '',
  address_complement: '',
});
const form = ref(emptyForm());

// Postal code lookup (ViaCEP). Plain fetch on purpose: the app's axios instance carries auth headers.
const postalCodeMessage = ref('');
const postalCodeNotFound = ref(false);
const lookupPostalCode = async postalCode => {
  const cep = (postalCode || '').replace(/\D/g, '');
  postalCodeMessage.value = '';
  postalCodeNotFound.value = false;
  if (cep.length !== 8) return;
  try {
    const response = await fetch(`https://viacep.com.br/ws/${cep}/json/`, {
      credentials: 'omit',
    });
    const data = await response.json();
    if (data.erro) {
      postalCodeNotFound.value = true;
      postalCodeMessage.value = t('CUSTOM_BILLING.MODAL.POSTAL_CODE_NOT_FOUND');
      return;
    }
    if (data.logradouro) form.value.address = data.logradouro;
    if (data.bairro) form.value.province = data.bairro;
    postalCodeMessage.value = t('CUSTOM_BILLING.MODAL.CITY', {
      city: `${data.localidade} - ${data.uf}`,
    });
  } catch {
    postalCodeMessage.value = '';
  }
};
watch(() => form.value.postal_code, lookupPostalCode);

const intlLocale = computed(() => locale.value.replace('_', '-'));
const formatMoney = cents =>
  new Intl.NumberFormat(intlLocale.value, {
    style: 'currency',
    currency: 'BRL',
  }).format((cents || 0) / 100);
const formatDate = value => {
  if (!value) return '';
  const date =
    value.length === 10 ? new Date(`${value}T00:00:00`) : new Date(value);
  return date.toLocaleDateString(intlLocale.value);
};
const priceFor = numbers => Math.max(numbers - 1, 0) * PRICE_PER_NUMBER_CENTS;

const isPaid = computed(() => Boolean(summary.value.credit_card_last4));
const isPastDue = computed(() => summary.value.status === 'past_due');
const inTrial = computed(
  () => Boolean(summary.value.in_trial) && !isPaid.value
);
const usageLimit = computed(
  () =>
    summary.value.effective_waba_limit || summary.value.allowed_waba_count || 1
);
const usagePercent = computed(() =>
  Math.min(
    100,
    Math.round(
      ((summary.value.connected_waba_count || 0) / usageLimit.value) * 100
    )
  )
);
const pausedCount = computed(() => summary.value.paused_inbox_ids?.length || 0);

const planLabel = computed(() => {
  if (isPastDue.value) return t('CUSTOM_BILLING.PLAN.PAST_DUE');
  if (isPaid.value) return t('CUSTOM_BILLING.PLAN.PAID');
  if (inTrial.value) return t('CUSTOM_BILLING.PLAN.TRIAL');
  return t('CUSTOM_BILLING.PLAN.FREE');
});
const monthlyLabel = computed(() =>
  summary.value.monthly_amount_cents
    ? t('CUSTOM_BILLING.PLAN.PER_MONTH', {
        amount: formatMoney(summary.value.monthly_amount_cents),
      })
    : t('CUSTOM_BILLING.PLAN.FREE_PRICE')
);

const currentNumbers = computed(() => summary.value.allowed_waba_count || 1);
const isCurrentSelection = computed(
  () => selectedNumbers.value === currentNumbers.value
);
const isDowngradeToFree = computed(
  () => isPaid.value && selectedNumbers.value === 1
);
const selectedPrice = computed(() => priceFor(selectedNumbers.value));
const todayDay = computed(() => new Date().getDate());

const applyLabel = computed(() => {
  if (isCurrentSelection.value) return t('CUSTOM_BILLING.ADJUST.CURRENT');
  if (isDowngradeToFree.value) return t('CUSTOM_BILLING.ADJUST.DOWNGRADE');
  const params = {
    count: selectedNumbers.value,
    amount: formatMoney(selectedPrice.value),
  };
  return isPaid.value
    ? t('CUSTOM_BILLING.ADJUST.CHANGE', params)
    : t('CUSTOM_BILLING.ADJUST.SUBSCRIBE', params);
});

const errorMessage = (error, fallback) =>
  error?.response?.data?.error || fallback;

const fetchSummary = async () => {
  try {
    const { data } = await CustomBillingAPI.getSummary();
    summary.value = data;
    selectedNumbers.value = data.allowed_waba_count || 1;
  } catch (error) {
    useAlert(errorMessage(error, t('CUSTOM_BILLING.LOAD_ERROR')));
  }
};

const fetchInvoices = async () => {
  try {
    const { data } = await CustomBillingAPI.getInvoices();
    invoices.value = data || [];
  } catch {
    invoices.value = [];
  }
};

const refresh = async () => {
  await Promise.all([fetchSummary(), fetchInvoices()]);
};

const openDialog = mode => {
  dialogMode.value = mode;
  form.value = emptyForm();
  dialogRef.value?.open();
};

const applyPlan = async () => {
  if (selectedNumbers.value > 1 && !isPaid.value) {
    openDialog('subscribe');
    return;
  }
  submitting.value = true;
  try {
    await CustomBillingAPI.updateSlots(selectedNumbers.value);
    useAlert(t('CUSTOM_BILLING.ADJUST.SUCCESS'));
    await refresh();
  } catch (error) {
    useAlert(errorMessage(error, t('CUSTOM_BILLING.ADJUST.ERROR')));
  } finally {
    submitting.value = false;
  }
};

const cardPayload = () => ({
  holder_name: form.value.holder_name,
  number: form.value.number,
  expiry_month: form.value.expiry_month,
  expiry_year: form.value.expiry_year,
  ccv: form.value.ccv,
});

const submitCard = async () => {
  submitting.value = true;
  try {
    if (dialogMode.value === 'update_card') {
      await CustomBillingAPI.updateCard({ card: cardPayload() });
      useAlert(t('CUSTOM_BILLING.MODAL.CARD_SUCCESS'));
    } else {
      await CustomBillingAPI.subscribe({
        total_numbers: selectedNumbers.value,
        card: cardPayload(),
        holder: {
          name: form.value.holder_name,
          cpf_cnpj: form.value.cpf_cnpj,
          phone: form.value.phone,
          postal_code: form.value.postal_code,
          province: form.value.province,
          address: form.value.address,
          address_number: form.value.address_number,
          address_complement: form.value.address_complement,
        },
      });
      useAlert(t('CUSTOM_BILLING.MODAL.SUBSCRIBE_SUCCESS'));
    }
    dialogRef.value?.close();
    await refresh();
  } catch (error) {
    useAlert(errorMessage(error, t('CUSTOM_BILLING.MODAL.ERROR')));
  } finally {
    submitting.value = false;
  }
};

const invoiceStatusLabel = status => {
  if (['CONFIRMED', 'RECEIVED', 'RECEIVED_IN_CASH'].includes(status)) {
    return t('CUSTOM_BILLING.INVOICES.STATUS.PAID');
  }
  if (status === 'OVERDUE') return t('CUSTOM_BILLING.INVOICES.STATUS.OVERDUE');
  return t('CUSTOM_BILLING.INVOICES.STATUS.PENDING');
};
const invoiceStatusColor = status => {
  if (['CONFIRMED', 'RECEIVED', 'RECEIVED_IN_CASH'].includes(status)) {
    return 'teal';
  }
  return status === 'OVERDUE' ? 'ruby' : 'amber';
};

const dialogTitle = computed(() =>
  dialogMode.value === 'update_card'
    ? t('CUSTOM_BILLING.MODAL.UPDATE_CARD_TITLE')
    : t('CUSTOM_BILLING.MODAL.SUBSCRIBE_TITLE', {
        count: selectedNumbers.value,
      })
);
const dialogConfirmLabel = computed(() =>
  dialogMode.value === 'update_card'
    ? t('CUSTOM_BILLING.MODAL.CONFIRM_CARD')
    : t('CUSTOM_BILLING.MODAL.CONFIRM_SUBSCRIBE')
);

onMounted(async () => {
  await refresh();
  loading.value = false;
});
</script>

<template>
  <div class="flex flex-col w-full gap-6 pb-12">
    <BaseSettingsHeader
      :title="t('CUSTOM_BILLING.TITLE')"
      :description="t('CUSTOM_BILLING.DESCRIPTION')"
    />

    <div v-if="loading" class="flex justify-center py-12">
      <Spinner />
    </div>

    <template v-else>
      <Banner v-if="isPastDue" color="ruby">
        {{ t('CUSTOM_BILLING.PAST_DUE_NOTICE') }}
      </Banner>
      <Banner v-if="pausedCount" color="ruby">
        {{ t('CUSTOM_BILLING.PAUSED_NOTICE', { count: pausedCount }) }}
      </Banner>
      <Banner v-if="inTrial" color="amber">
        {{
          t('CUSTOM_BILLING.TRIAL_NOTICE', {
            date: formatDate(summary.trial_ends_at),
            limit: summary.effective_waba_limit,
          })
        }}
      </Banner>

      <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div class="flex flex-col gap-6 lg:col-span-2">
          <section class="p-6 border rounded-xl border-n-weak">
            <div
              class="flex flex-wrap items-start justify-between gap-4 pb-4 border-b border-n-weak"
            >
              <div class="flex items-center gap-2">
                <span class="text-heading-3 text-n-slate-12">
                  {{ planLabel }}
                </span>
              </div>
              <div class="text-end">
                <span class="block text-body-main text-n-slate-11">
                  {{ t('CUSTOM_BILLING.PLAN.MONTHLY') }}
                </span>
                <span class="text-heading-3 text-n-slate-12">
                  {{ monthlyLabel }}
                </span>
              </div>
            </div>

            <div class="flex flex-col gap-2 mt-4">
              <div
                class="flex items-center justify-between text-body-main text-n-slate-12"
              >
                <span>{{ t('CUSTOM_BILLING.USAGE.TITLE') }}</span>
                <span>
                  {{
                    t('CUSTOM_BILLING.USAGE.COUNT', {
                      used: summary.connected_waba_count || 0,
                      limit: usageLimit,
                    })
                  }}
                </span>
              </div>
              <div class="w-full h-2 overflow-hidden rounded-full bg-n-alpha-2">
                <div
                  class="h-2 rounded-full bg-n-brand transition-all"
                  :style="{ width: `${usagePercent}%` }"
                />
              </div>
              <span class="text-sm text-n-slate-11">
                {{ t('CUSTOM_BILLING.USAGE.NOTE') }}
              </span>
            </div>

            <div
              v-if="isPaid && summary.billing_day"
              class="flex flex-col gap-1 p-3 mt-4 rounded-lg bg-n-alpha-2 text-body-main text-n-slate-12"
            >
              <span class="font-medium">
                {{
                  t('CUSTOM_BILLING.BILLING_DAY', {
                    day: summary.billing_day,
                    last4: summary.credit_card_last4,
                  })
                }}
              </span>
              <span class="text-n-slate-11">
                {{
                  t('CUSTOM_BILLING.NEXT_CHARGE', {
                    date: formatDate(summary.next_due_date),
                    amount: formatMoney(summary.monthly_amount_cents),
                  })
                }}
              </span>
            </div>
          </section>

          <section class="p-6 border rounded-xl border-n-weak">
            <h3 class="mb-1 text-heading-3 text-n-slate-12">
              {{ t('CUSTOM_BILLING.ADJUST.TITLE') }}
            </h3>
            <p class="mb-5 text-body-main text-n-slate-11">
              {{
                t('CUSTOM_BILLING.ADJUST.DESCRIPTION', {
                  price: formatMoney(PRICE_PER_NUMBER_CENTS),
                })
              }}
            </p>

            <div
              class="flex flex-wrap items-center justify-between gap-4 p-4 rounded-lg bg-n-alpha-2"
            >
              <div class="flex items-center gap-3">
                <Button
                  icon="i-lucide-minus"
                  slate
                  sm
                  :aria-label="t('CUSTOM_BILLING.ADJUST.DECREASE')"
                  :disabled="selectedNumbers <= 1"
                  @click="selectedNumbers -= 1"
                />
                <span
                  class="text-heading-2 text-n-slate-12 min-w-28 text-center"
                >
                  {{ t('CUSTOM_BILLING.ADJUST.NUMBERS', selectedNumbers) }}
                </span>
                <Button
                  icon="i-lucide-plus"
                  slate
                  sm
                  :aria-label="t('CUSTOM_BILLING.ADJUST.INCREASE')"
                  :disabled="selectedNumbers >= MAX_NUMBERS"
                  @click="selectedNumbers += 1"
                />
              </div>
              <div class="text-end">
                <span class="block text-sm text-n-slate-11">
                  {{ t('CUSTOM_BILLING.ADJUST.NEW_PRICE') }}
                </span>
                <span class="text-heading-2 text-n-slate-12">
                  {{
                    selectedPrice
                      ? t('CUSTOM_BILLING.PLAN.PER_MONTH', {
                          amount: formatMoney(selectedPrice),
                        })
                      : t('CUSTOM_BILLING.PLAN.FREE_PRICE')
                  }}
                </span>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-2 mt-3 sm:grid-cols-4">
              <div
                v-for="numbers in PRICE_TABLE"
                :key="numbers"
                class="p-2 text-center border rounded-lg border-n-weak"
              >
                <span class="block text-sm text-n-slate-11">
                  {{ t('CUSTOM_BILLING.ADJUST.NUMBERS', numbers) }}
                </span>
                <span class="text-sm font-medium text-n-slate-12">
                  {{
                    priceFor(numbers)
                      ? t('CUSTOM_BILLING.ADJUST.TABLE_PRICE', {
                          amount: formatMoney(priceFor(numbers)),
                        })
                      : t('CUSTOM_BILLING.PLAN.FREE_PRICE')
                  }}
                </span>
              </div>
            </div>

            <p
              v-if="isPaid && !isCurrentSelection && !isDowngradeToFree"
              class="mt-4 text-sm text-n-slate-11"
            >
              {{
                t('CUSTOM_BILLING.ADJUST.CHANGE_NOTE', {
                  day: summary.billing_day,
                })
              }}
            </p>
            <p v-if="isDowngradeToFree" class="mt-4 text-sm text-n-ruby-11">
              {{ t('CUSTOM_BILLING.ADJUST.DOWNGRADE_NOTE') }}
            </p>

            <div class="flex justify-end mt-5">
              <Button
                :label="applyLabel"
                :color="isDowngradeToFree ? 'ruby' : 'blue'"
                :disabled="isCurrentSelection || submitting"
                :is-loading="submitting"
                @click="applyPlan"
              />
            </div>
          </section>
        </div>

        <div class="flex flex-col gap-6">
          <section class="p-6 border rounded-xl border-n-weak">
            <h4 class="mb-3 text-heading-3 text-n-slate-12">
              {{ t('CUSTOM_BILLING.CARD.TITLE') }}
            </h4>
            <template v-if="isPaid">
              <p class="text-body-main text-n-slate-12">
                {{
                  t('CUSTOM_BILLING.CARD.ENDING', {
                    brand: summary.credit_card_brand || '',
                    last4: summary.credit_card_last4,
                  })
                }}
              </p>
              <Button
                class="w-full mt-4"
                slate
                sm
                :label="t('CUSTOM_BILLING.CARD.CHANGE')"
                @click="openDialog('update_card')"
              />
            </template>
            <p v-else class="text-body-main text-n-slate-11">
              {{ t('CUSTOM_BILLING.CARD.NONE') }}
            </p>
          </section>

          <section class="p-6 border rounded-xl border-n-weak">
            <h4 class="mb-3 text-heading-3 text-n-slate-12">
              {{ t('CUSTOM_BILLING.INVOICES.TITLE') }}
            </h4>
            <p v-if="!invoices.length" class="text-body-main text-n-slate-11">
              {{ t('CUSTOM_BILLING.INVOICES.EMPTY') }}
            </p>
            <ul v-else class="flex flex-col gap-2">
              <li
                v-for="invoice in invoices"
                :key="invoice.id"
                class="flex items-center justify-between gap-2 p-2 border rounded-lg border-n-weak"
              >
                <div class="flex flex-col">
                  <span class="text-body-main text-n-slate-12">
                    {{ formatMoney(invoice.amount_cents) }}
                  </span>
                  <span class="text-sm text-n-slate-11">
                    {{ formatDate(invoice.payment_date || invoice.due_date) }}
                  </span>
                </div>
                <div class="flex items-center gap-2">
                  <Label
                    :label="invoiceStatusLabel(invoice.status)"
                    :color="invoiceStatusColor(invoice.status)"
                    compact
                  />
                  <a
                    v-if="invoice.invoice_url"
                    :href="invoice.invoice_url"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-sm text-n-brand hover:underline"
                  >
                    {{ t('CUSTOM_BILLING.INVOICES.RECEIPT') }}
                  </a>
                </div>
              </li>
            </ul>
          </section>
        </div>
      </div>
    </template>

    <Dialog
      ref="dialogRef"
      :title="dialogTitle"
      :confirm-button-label="dialogConfirmLabel"
      :is-loading="submitting"
      width="lg"
      overflow-y-auto
      @confirm="submitCard"
    >
      <div class="flex flex-col gap-4">
        <div
          v-if="dialogMode === 'subscribe'"
          class="flex flex-col gap-1 p-3 rounded-lg bg-n-alpha-2 text-body-main text-n-slate-12"
        >
          <span class="font-medium">
            {{
              t('CUSTOM_BILLING.MODAL.SUMMARY_TODAY', {
                amount: formatMoney(selectedPrice),
              })
            }}
          </span>
          <span>
            {{
              t('CUSTOM_BILLING.MODAL.SUMMARY_RECURRING', {
                amount: formatMoney(selectedPrice),
                day: todayDay,
              })
            }}
          </span>
        </div>

        <span class="text-sm font-medium text-n-slate-11">
          {{ t('CUSTOM_BILLING.MODAL.CARD_SECTION') }}
        </span>
        <Input
          v-model="form.holder_name"
          :label="t('CUSTOM_BILLING.MODAL.HOLDER_NAME')"
        />
        <Input
          v-model="form.number"
          :label="t('CUSTOM_BILLING.MODAL.NUMBER')"
        />
        <div class="grid grid-cols-3 gap-3">
          <Input
            v-model="form.expiry_month"
            :label="t('CUSTOM_BILLING.MODAL.EXPIRY_MONTH')"
          />
          <Input
            v-model="form.expiry_year"
            :label="t('CUSTOM_BILLING.MODAL.EXPIRY_YEAR')"
          />
          <Input v-model="form.ccv" :label="t('CUSTOM_BILLING.MODAL.CVV')" />
        </div>

        <template v-if="dialogMode === 'subscribe'">
          <span class="text-sm font-medium text-n-slate-11">
            {{ t('CUSTOM_BILLING.MODAL.HOLDER_SECTION') }}
          </span>
          <div class="grid grid-cols-2 gap-3">
            <Input
              v-model="form.cpf_cnpj"
              :label="t('CUSTOM_BILLING.MODAL.CPF_CNPJ')"
            />
            <Input
              v-model="form.phone"
              :label="t('CUSTOM_BILLING.MODAL.PHONE')"
            />
            <Input
              v-model="form.postal_code"
              :label="t('CUSTOM_BILLING.MODAL.POSTAL_CODE')"
              :message="postalCodeMessage"
              :message-type="postalCodeNotFound ? 'error' : 'info'"
            />
            <Input
              v-model="form.province"
              :label="t('CUSTOM_BILLING.MODAL.PROVINCE')"
            />
            <Input
              v-model="form.address"
              class="col-span-2"
              :label="t('CUSTOM_BILLING.MODAL.STREET')"
            />
            <Input
              v-model="form.address_number"
              :label="t('CUSTOM_BILLING.MODAL.ADDRESS_NUMBER')"
            />
            <Input
              v-model="form.address_complement"
              :label="t('CUSTOM_BILLING.MODAL.COMPLEMENT')"
            />
          </div>
        </template>

        <p class="text-sm text-n-slate-11">
          {{ t('CUSTOM_BILLING.MODAL.SECURITY_NOTE') }}
        </p>
      </div>
    </Dialog>
  </div>
</template>
