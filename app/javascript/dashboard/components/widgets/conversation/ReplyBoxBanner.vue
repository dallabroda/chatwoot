<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { isAIAssigneeType } from 'dashboard/helper/agentHelper';
import ConversationApi from 'dashboard/api/inbox/conversation';
import wootConstants from 'dashboard/constants/globals';

import Banner from 'dashboard/components/ui/Banner.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import WhatsappQrReconnectDialog from 'dashboard/routes/dashboard/settings/inbox/components/WhatsappQrReconnectDialog.vue';

const props = defineProps({
  message: {
    type: String,
    default: '',
  },
  isOnPrivateNote: {
    type: Boolean,
    default: false,
  },
});

const store = useStore();
const { t } = useI18n();

const currentChat = useMapGetter('getSelectedChat');
const currentUser = useMapGetter('getCurrentUser');

const assignedAgent = computed(() => currentChat.value?.meta?.assignee);

const { isAdmin } = useAdmin();
const qrReconnectDialog = ref(null);
const currentInbox = computed(() =>
  store.getters['inboxes/getInbox']?.(currentChat.value?.inbox_id)
);
const showQrDisconnectedBanner = computed(() => {
  const attributes = currentInbox.value?.additional_attributes;
  return (
    attributes?.connection_type === 'evolution_qr' &&
    attributes?.connection_state !== 'connected'
  );
});

const showSelfAssignBanner = computed(
  () =>
    props.message !== '' &&
    !props.isOnPrivateNote &&
    (!assignedAgent.value || assignedAgent.value.id !== currentUser.value?.id)
);

const showBotHandoffBanner = computed(
  () =>
    currentChat.value?.status === wootConstants.STATUS_TYPE.PENDING &&
    isAIAssigneeType(currentChat.value?.meta?.assignee_type)
);

const botAssigneeName = computed(
  () =>
    assignedAgent.value?.name || t('CONVERSATION.BOT_HANDOFF_FALLBACK_ASSIGNEE')
);

const selfAssignConversation = async conversationId => {
  const { data } = await ConversationApi.assignAgent({
    conversationId,
    agentId: currentUser.value.id,
    assigneeType: 'User',
  });
  await store.dispatch('setCurrentChatAssignee', {
    conversationId,
    assignee: data,
    assigneeType: 'User',
  });
};

const onClickSelfAssign = async () => {
  try {
    await selfAssignConversation(currentChat.value.id);
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } catch (error) {
    useAlert(t('CONVERSATION.CHANGE_AGENT_FAILED'));
  }
};

const onClickBotHandoff = async () => {
  const conversationId = currentChat.value.id;
  try {
    await selfAssignConversation(conversationId);
    store.commit('CHANGE_CONVERSATION_STATUS', {
      conversationId,
      status: 'open',
      snoozedUntil: null,
    });
    useAlert(t('CONVERSATION.BOT_HANDOFF_SUCCESS'));
  } catch (error) {
    useAlert(t('CONVERSATION.BOT_HANDOFF_ERROR'));
  }
};
</script>

<template>
  <Banner
    v-if="showQrDisconnectedBanner"
    action-button-variant="ghost"
    color-scheme="alert"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="
      isAdmin
        ? $t('INBOX_MGMT.QR_CONNECTION.DISCONNECTED_BANNER')
        : $t('INBOX_MGMT.QR_CONNECTION.DISCONNECTED_BANNER_AGENT')
    "
    :has-action-button="isAdmin"
    :action-button-label="$t('INBOX_MGMT.QR_CONNECTION.RECONNECT_BUTTON')"
    @primary-action="qrReconnectDialog.open()"
  />
  <WhatsappQrReconnectDialog
    v-if="showQrDisconnectedBanner && isAdmin"
    ref="qrReconnectDialog"
    :inbox-id="currentInbox.id"
  />
  <Banner
    v-if="showSelfAssignBanner && !showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="$t('CONVERSATION.NOT_ASSIGNED_TO_YOU')"
    has-action-button
    :action-button-label="$t('CONVERSATION.ASSIGN_TO_ME')"
    @primary-action="onClickSelfAssign"
  />
  <Banner
    v-if="showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="
      $t('CONVERSATION.BOT_HANDOFF_MESSAGE', {
        assigneeName: botAssigneeName,
      })
    "
    has-action-button
    :action-button-label="$t('CONVERSATION.BOT_HANDOFF_ACTION')"
    @primary-action="onClickBotHandoff"
  />
</template>
