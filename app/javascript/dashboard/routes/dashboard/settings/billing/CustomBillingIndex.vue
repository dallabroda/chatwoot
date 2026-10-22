<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';
import CustomBillingAPI from 'dashboard/api/customBilling';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const loading = ref(true);
const submitting = ref(false);
const summary = ref({
  allowed_waba_count: 1,
  connected_waba_count: 0,
  status: 'free',
  monthly_amount_cents: 0,
  credit_card_last4: null,
  credit_card_brand: null,
  next_due_date: null,
  can_add_more: true,
});

const selectedSlots = ref(1);
const isCardModalOpen = ref(false);
const modalMode = ref('subscribe'); // 'subscribe' or 'update_card'

const cardForm = ref({
  holder_name: '',
  number: '',
  expiry_month: '',
  expiry_year: '',
  ccv: '',
  name: '',
  email: '',
  cpf_cnpj: '',
  phone: '',
  postal_code: '',
  address_number: '',
});

const invoices = ref([]);
const loadingInvoices = ref(false);

const calculatedPrice = computed(() => {
  if (selectedSlots.value <= 1) return 0;
  return (selectedSlots.value - 1) * 60;
});

const currentMonthlyReais = computed(() => {
  return (summary.value.monthly_amount_cents / 100).toFixed(2);
});

const hasActiveCard = computed(() => {
  return !!summary.value.credit_card_last4;
});

const usagePercentage = computed(() => {
  if (!summary.value.allowed_waba_count) return 0;
  return Math.min(
    100,
    Math.round((summary.value.connected_waba_count / summary.value.allowed_waba_count) * 100)
  );
});

const isCurrentSlotCount = computed(() => {
  return selectedSlots.value === summary.value.allowed_waba_count;
});

const fetchSummary = async () => {
  loading.value = true;
  try {
    const { data } = await CustomBillingAPI.getSummary();
    summary.value = data;
    selectedSlots.value = data.allowed_waba_count || 1;
  } catch (error) {
    useAlert(error?.response?.data?.error || 'Erro ao carregar dados do plano.');
  } finally {
    loading.value = false;
  }
};

const fetchInvoices = async () => {
  loadingInvoices.value = true;
  try {
    const { data } = await CustomBillingAPI.getInvoices();
    invoices.value = data || [];
  } catch (error) {
    // Silencioso em caso de erro secundário
  } finally {
    loadingInvoices.value = false;
  }
};

const incrementSlot = () => {
  if (selectedSlots.value < 50) {
    selectedSlots.value += 1;
  }
};

const decrementSlot = () => {
  if (selectedSlots.value > 1) {
    selectedSlots.value -= 1;
  }
};

const handleApplyPlan = async () => {
  // Se for plano pago (2+) e não tiver cartão cadastrado, abre o modal
  if (selectedSlots.value > 1 && !hasActiveCard.value) {
    modalMode.value = 'subscribe';
    isCardModalOpen.value = true;
    return;
  }

  submitting.value = true;
  try {
    const { data } = await CustomBillingAPI.updateSlots(selectedSlots.value);
    useAlert(data.message || 'Plano atualizado com sucesso!');
    await fetchSummary();
  } catch (error) {
    useAlert(error?.response?.data?.error || 'Erro ao atualizar plano.');
  } finally {
    submitting.value = false;
  }
};

const openUpdateCardModal = () => {
  modalMode.value = 'update_card';
  isCardModalOpen.value = true;
};

const handleCardFormSubmit = async () => {
  submitting.value = true;
  try {
    if (modalMode.value === 'update_card') {
      const { data } = await CustomBillingAPI.updateCard({
        card: {
          holder_name: cardForm.value.holder_name,
          number: cardForm.value.number,
          expiry_month: cardForm.value.expiry_month,
          expiry_year: cardForm.value.expiry_year,
          ccv: cardForm.value.ccv,
        },
      });
      useAlert(data.message || 'Cartão atualizado com sucesso!');
    } else {
      const payload = {
        total_numbers: selectedSlots.value,
        card: {
          holder_name: cardForm.value.holder_name,
          number: cardForm.value.number,
          expiry_month: cardForm.value.expiry_month,
          expiry_year: cardForm.value.expiry_year,
          ccv: cardForm.value.ccv,
        },
        holder: {
          name: cardForm.value.name || cardForm.value.holder_name,
          email: cardForm.value.email,
          cpf_cnpj: cardForm.value.cpf_cnpj,
          phone: cardForm.value.phone,
          postal_code: cardForm.value.postal_code,
          address_number: cardForm.value.address_number,
        },
      };
      const { data } = await CustomBillingAPI.subscribe(payload);
      useAlert(data.message || 'Assinatura realizada com sucesso!');
    }
    isCardModalOpen.value = false;
    await fetchSummary();
    await fetchInvoices();
  } catch (error) {
    useAlert(error?.response?.data?.error || 'Erro ao processar cartão.');
  } finally {
    submitting.value = false;
  }
};

onMounted(() => {
  fetchSummary();
  fetchInvoices();
});
</script>

<template>
  <div class="flex flex-col w-full pb-12">
    <BaseSettingsHeader
      title="Plano & Faturamento"
      description="Gerencie as conexões de WhatsApp do seu sistema e o método de pagamento."
    />

    <!-- Alerta de Inadimplência -->
    <div
      v-if="summary.status === 'past_due'"
      class="mt-4 p-4 rounded-xl bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-900/60 flex items-start gap-3"
    >
      <div class="i-lucide-alert-triangle text-red-600 text-xl flex-shrink-0 mt-0.5" />
      <div>
        <h4 class="text-sm font-semibold text-red-900 dark:text-red-200">
          Pagamento pendente no Cartão de Crédito
        </h4>
        <p class="text-xs text-red-700 dark:text-red-300 mt-1">
          A última renovação da sua mensalidade não foi aprovada pelo banco emissor. Atualize o seu cartão abaixo para evitar a suspensão temporária dos seus números adicionais.
        </p>
      </div>
    </div>

    <div v-if="loading" class="mt-8 flex justify-center py-12">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-500" />
    </div>

    <div v-else class="mt-6 grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Coluna Principal (2/3) -->
      <div class="lg:col-span-2 space-y-6">
        <!-- Card 1: Consumo Atual -->
        <div class="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-6 shadow-sm">
          <div class="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800">
            <div>
              <span class="text-xs font-semibold tracking-wider uppercase text-slate-400">Status da Conta</span>
              <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 flex items-center gap-2 mt-0.5">
                <span
                  class="w-2.5 h-2.5 rounded-full"
                  :class="summary.status === 'past_due' ? 'bg-red-500' : 'bg-emerald-500'"
                />
                {{ summary.allowed_waba_count <= 1 ? 'Plano Gratuito' : 'Plano Pro Recorrente' }}
              </h3>
            </div>
            <div class="text-right">
              <span class="text-xs text-slate-400">Mensalidade Atual</span>
              <p class="text-lg font-bold text-emerald-600 dark:text-emerald-400">
                {{ summary.monthly_amount_cents === 0 ? 'Grátis' : `R$ ${currentMonthlyReais} / mês` }}
              </p>
            </div>
          </div>

          <div class="mt-6">
            <div class="flex justify-between items-center text-sm font-medium text-slate-700 dark:text-slate-200 mb-2">
              <span class="flex items-center gap-2">
                <i class="i-lucide-smartphone text-emerald-600" />
                Conexões de WhatsApp em Uso
              </span>
              <span>{{ summary.connected_waba_count }} de {{ summary.allowed_waba_count }} permitidos</span>
            </div>
            <div class="w-full bg-slate-100 dark:bg-slate-800 rounded-full h-3 overflow-hidden">
              <div
                class="bg-emerald-500 h-3 rounded-full transition-all duration-500"
                :style="{ width: `${usagePercentage}%` }"
              />
            </div>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-2">
              * Inclui números conectados via WhatsApp Cloud API (Oficial) e QR Code.
            </p>
          </div>
        </div>

        <!-- Card 2: Seletor de Upgrade / Downgrade -->
        <div class="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-6 shadow-sm">
          <h3 class="text-base font-bold text-slate-800 dark:text-slate-100 mb-1">
            Ajustar Quantidade de Números
          </h3>
          <p class="text-xs text-slate-500 dark:text-slate-400 mb-6">
            Escolha quantos números de WhatsApp a sua empresa precisa. 1 número é gratuito; a partir do 2º, são R$ 60,00 por número adicional.
          </p>

          <!-- Seletor Interativo -->
          <div class="flex flex-col sm:flex-row items-center justify-between p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200/80 dark:border-slate-700/60 gap-4">
            <div class="flex items-center gap-3">
              <button
                type="button"
                @click="decrementSlot"
                :disabled="selectedSlots <= 1"
                class="w-10 h-10 rounded-lg flex items-center justify-center font-bold text-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 disabled:opacity-40 disabled:cursor-not-allowed shadow-sm transition"
              >
                -
              </button>
              <div class="w-16 text-center">
                <span class="text-2xl font-black text-slate-900 dark:text-white">{{ selectedSlots }}</span>
                <span class="block text-[11px] text-slate-400 uppercase font-semibold">
                  {{ selectedSlots === 1 ? 'número' : 'números' }}
                </span>
              </div>
              <button
                type="button"
                @click="incrementSlot"
                :disabled="selectedSlots >= 50"
                class="w-10 h-10 rounded-lg flex items-center justify-center font-bold text-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 disabled:opacity-40 disabled:cursor-not-allowed shadow-sm transition"
              >
                +
              </button>
            </div>

            <div class="text-center sm:text-right">
              <span class="text-xs font-semibold uppercase text-slate-400">Novo Valor Previsto</span>
              <div class="text-2xl font-black text-emerald-600 dark:text-emerald-400">
                {{ calculatedPrice === 0 ? 'Grátis' : `R$ ${calculatedPrice},00 / mês` }}
              </div>
            </div>
          </div>

          <!-- Tabela de Preços Informativa -->
          <div class="mt-4 grid grid-cols-2 sm:grid-cols-4 gap-2 text-center text-xs">
            <div class="p-2 rounded-lg bg-slate-50 dark:bg-slate-800/30 border border-slate-100 dark:border-slate-800">
              <span class="block text-slate-400">1 Número</span>
              <strong class="text-emerald-600 font-bold">Grátis</strong>
            </div>
            <div class="p-2 rounded-lg bg-slate-50 dark:bg-slate-800/30 border border-slate-100 dark:border-slate-800">
              <span class="block text-slate-400">2 Números</span>
              <strong class="text-slate-700 dark:text-slate-200 font-bold">R$ 60/mês</strong>
            </div>
            <div class="p-2 rounded-lg bg-slate-50 dark:bg-slate-800/30 border border-slate-100 dark:border-slate-800">
              <span class="block text-slate-400">3 Números</span>
              <strong class="text-slate-700 dark:text-slate-200 font-bold">R$ 120/mês</strong>
            </div>
            <div class="p-2 rounded-lg bg-slate-50 dark:bg-slate-800/30 border border-slate-100 dark:border-slate-800">
              <span class="block text-slate-400">4 Números</span>
              <strong class="text-slate-700 dark:text-slate-200 font-bold">R$ 180/mês</strong>
            </div>
          </div>

          <!-- Botão de Ação -->
          <div class="mt-6 flex justify-end">
            <button
              type="button"
              @click="handleApplyPlan"
              :disabled="isCurrentSlotCount || submitting"
              class="px-6 py-3 rounded-xl font-bold text-sm shadow-md transition flex items-center justify-center gap-2"
              :style="isCurrentSlotCount ? 'background-color: #f1f5f9; color: #94a3b8; border: 1px solid #cbd5e1; cursor: not-allowed;' : 'background-color: #1f93ff; color: #ffffff; cursor: pointer;'"
            >
              <span v-if="submitting" class="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
              <span v-if="isCurrentSlotCount">Plano Selecionado é o Atual ({{ summary.allowed_waba_count }} número)</span>
              <span v-else-if="selectedSlots > 1 && !hasActiveCard">
                💳 Comprar / Assinar {{ selectedSlots }} Números (R$ {{ calculatedPrice }},00 / mês)
              </span>
              <span v-else>
                Confirmar Alteração para {{ selectedSlots }} Números (R$ {{ calculatedPrice }},00 / mês)
              </span>
            </button>
          </div>
        </div>
      </div>

      <!-- Coluna Lateral (1/3) -->
      <div class="space-y-6">
        <!-- Card 3: Método de Pagamento (Cartão) -->
        <div class="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-6 shadow-sm">
          <h4 class="text-sm font-bold text-slate-800 dark:text-slate-100 mb-3 flex items-center gap-2">
            <i class="i-lucide-credit-card text-woot-500" />
            Cartão de Crédito
          </h4>

          <div v-if="hasActiveCard" class="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700">
            <div class="flex items-center justify-between mb-2">
              <span class="text-xs uppercase font-bold tracking-wider text-slate-400">
                {{ summary.credit_card_brand || 'Cartão' }}
              </span>
              <span class="text-xs font-medium text-emerald-600 bg-emerald-50 dark:bg-emerald-950 px-2 py-0.5 rounded-full">
                Ativo
              </span>
            </div>
            <div class="text-base font-mono font-bold text-slate-800 dark:text-slate-100">
              •••• •••• •••• {{ summary.credit_card_last4 }}
            </div>
            <p v-if="summary.next_due_date" class="text-[11px] text-slate-400 mt-2">
              Próxima renovação: {{ summary.next_due_date }}
            </p>

            <button
              type="button"
              @click="openUpdateCardModal"
              class="mt-4 w-full py-2 px-3 rounded-lg text-xs font-semibold text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            >
              Trocar Cartão de Crédito
            </button>
          </div>

          <div v-else class="text-center py-6 px-4 rounded-xl bg-slate-50 dark:bg-slate-800/40 border border-dashed border-slate-200 dark:border-slate-700">
            <div class="i-lucide-shield-check text-2xl text-slate-400 mx-auto mb-2" />
            <p class="text-xs text-slate-500 dark:text-slate-400">
              Você está no plano gratuito. Nenhum cartão é necessário para gerenciar 1 número.
            </p>
            <button
              type="button"
              @click="() => { selectedSlots = 2; handleApplyPlan(); }"
              class="mt-3 inline-flex items-center justify-center px-4 py-2 rounded-lg text-xs font-bold shadow-sm transition"
              style="background-color: #1f93ff; color: #ffffff;"
            >
              + Contratar Mais Números
            </button>
          </div>
        </div>

        <!-- Card 4: Histórico de Faturas -->
        <div class="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-6 shadow-sm">
          <h4 class="text-sm font-bold text-slate-800 dark:text-slate-100 mb-3 flex items-center gap-2">
            <i class="i-lucide-receipt text-emerald-600" />
            Faturas Recentes
          </h4>

          <div v-if="loadingInvoices" class="py-4 text-center text-xs text-slate-400">
            Carregando recibos...
          </div>

          <div v-else-if="invoices.length === 0" class="py-6 text-center text-xs text-slate-400">
            Nenhuma fatura emitida até o momento.
          </div>

          <div v-else class="space-y-2">
            <div
              v-for="invoice in invoices"
              :key="invoice.id"
              class="flex items-center justify-between p-2.5 rounded-lg border border-slate-100 dark:border-slate-800 text-xs"
            >
              <div>
                <span class="font-semibold text-slate-800 dark:text-slate-200">
                  R$ {{ (invoice.amount_cents / 100).toFixed(2) }}
                </span>
                <span class="block text-[11px] text-slate-400">
                  {{ new Date(invoice.created_at).toLocaleDateString('pt-BR') }}
                </span>
              </div>
              <a
                v-if="invoice.invoice_url"
                :href="invoice.invoice_url"
                target="_blank"
                rel="noopener noreferrer"
                class="text-emerald-600 hover:underline font-semibold"
              >
                Comprovante ↗
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de Cartão de Crédito -->
    <div
      v-if="isCardModalOpen"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm"
    >
      <div class="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xl max-w-lg w-full p-6 max-h-[90vh] overflow-y-auto">
        <div class="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800">
          <h3 class="text-base font-bold text-slate-900 dark:text-white">
            {{ modalMode === 'update_card' ? 'Atualizar Cartão de Crédito' : `Assinar Plano (${selectedSlots} números)` }}
          </h3>
          <button
            type="button"
            @click="isCardModalOpen = false"
            class="text-slate-400 hover:text-slate-600 text-lg font-bold"
          >
            ✕
          </button>
        </div>

        <form @submit.prevent="handleCardFormSubmit" class="mt-4 space-y-4">
          <div v-if="modalMode !== 'update_card'" class="p-3 rounded-lg bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 text-xs text-emerald-800 dark:text-emerald-300">
            Você está contratando <strong>{{ selectedSlots }} números de WhatsApp</strong> por <strong>R$ {{ calculatedPrice }},00 / mês</strong> debitados automaticamente no cartão.
          </div>

          <!-- Dados do Cartão -->
          <div class="space-y-3">
            <span class="text-xs font-bold uppercase tracking-wider text-slate-400">Dados do Cartão</span>
            <div>
              <label class="block text-xs font-medium text-slate-700 dark:text-slate-300 mb-1">Nome impresso no Cartão</label>
              <input
                v-model="cardForm.holder_name"
                required
                type="text"
                placeholder="Ex: JOAO SILVA"
                class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-sm focus:ring-2 focus:ring-emerald-500 outline-none uppercase"
              />
            </div>

            <div>
              <label class="block text-xs font-medium text-slate-700 dark:text-slate-300 mb-1">Número do Cartão</label>
              <input
                v-model="cardForm.number"
                required
                type="text"
                maxlength="19"
                placeholder="0000 0000 0000 0000"
                class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-sm focus:ring-2 focus:ring-emerald-500 outline-none font-mono"
              />
            </div>

            <div class="grid grid-cols-3 gap-2">
              <div>
                <label class="block text-xs font-medium text-slate-700 dark:text-slate-300 mb-1">Mês (MM)</label>
                <input
                  v-model="cardForm.expiry_month"
                  required
                  type="text"
                  maxlength="2"
                  placeholder="12"
                  class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-sm text-center focus:ring-2 focus:ring-emerald-500 outline-none font-mono"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-slate-700 dark:text-slate-300 mb-1">Ano (AAAA)</label>
                <input
                  v-model="cardForm.expiry_year"
                  required
                  type="text"
                  maxlength="4"
                  placeholder="2028"
                  class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-sm text-center focus:ring-2 focus:ring-emerald-500 outline-none font-mono"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-slate-700 dark:text-slate-300 mb-1">CVV</label>
                <input
                  v-model="cardForm.ccv"
                  required
                  type="text"
                  maxlength="4"
                  placeholder="123"
                  class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-sm text-center focus:ring-2 focus:ring-emerald-500 outline-none font-mono"
                />
              </div>
            </div>
          </div>

          <!-- Dados do Titular (apenas ao assinar pela 1ª vez) -->
          <div v-if="modalMode !== 'update_card'" class="space-y-3 pt-3 border-t border-slate-100 dark:border-slate-800">
            <span class="text-xs font-bold uppercase tracking-wider text-slate-400">Titular do Cartão (Exigência Asaas)</span>

            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="block text-xs font-medium text-slate-700 dark:text-slate-300 mb-1">CPF ou CNPJ</label>
                <input
                  v-model="cardForm.cpf_cnpj"
                  required
                  type="text"
                  placeholder="000.000.000-00"
                  class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-slate-700 dark:text-slate-300 mb-1">Celular com DDD</label>
                <input
                  v-model="cardForm.phone"
                  required
                  type="text"
                  placeholder="(11) 99999-9999"
                  class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                />
              </div>
            </div>

            <div class="grid grid-cols-3 gap-2">
              <div class="col-span-2">
                <label class="block text-xs font-medium text-slate-700 dark:text-slate-300 mb-1">CEP</label>
                <input
                  v-model="cardForm.postal_code"
                  required
                  type="text"
                  placeholder="00000-000"
                  class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-slate-700 dark:text-slate-300 mb-1">Número</label>
                <input
                  v-model="cardForm.address_number"
                  required
                  type="text"
                  placeholder="100"
                  class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                />
              </div>
            </div>
          </div>

          <div class="pt-4 flex justify-end gap-2 border-t border-slate-100 dark:border-slate-800">
            <button
              type="button"
              @click="isCardModalOpen = false"
              class="px-4 py-2 rounded-xl text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition"
            >
              Cancelar
            </button>
            <button
              type="submit"
              :disabled="submitting"
              class="px-5 py-2.5 rounded-xl text-xs font-bold shadow-md transition flex items-center gap-2 cursor-pointer"
              style="background-color: #1f93ff; color: #ffffff;"
            >
              <span v-if="submitting" class="animate-spin rounded-full h-3 w-3 border-b-2 border-white" />
              <span>{{ modalMode === 'update_card' ? 'Salvar Cartão' : `Confirmar Assinatura (R$ ${calculatedPrice},00 / mês)` }}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>
