import { frontendURL } from '../../../helper/URLHelper';
import PhoneNumbersIndex from './pages/PhoneNumbersIndex.vue';
import WebhookEventsIndex from './pages/WebhookEventsIndex.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/phone-numbers'),
    name: 'phone_numbers_index',
    component: PhoneNumbersIndex,
    meta: {
      permissions: ['administrator'],
    },
  },
  {
    path: frontendURL('accounts/:accountId/phone-numbers/webhooks'),
    name: 'phone_numbers_webhooks',
    component: WebhookEventsIndex,
    meta: {
      permissions: ['administrator'],
    },
  },
];
