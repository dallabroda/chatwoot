import { frontendURL } from '../../../helper/URLHelper';
import { META_ASSET_TYPES } from './constants';
import MetaAssetsIndex from './pages/MetaAssetsIndex.vue';
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
  ...META_ASSET_TYPES.map(({ type, routeName }) => ({
    path: frontendURL(`accounts/:accountId/meta-assets/${type}`),
    name: routeName,
    component: MetaAssetsIndex,
    meta: {
      permissions: ['administrator'],
      assetType: type,
    },
  })),
];
