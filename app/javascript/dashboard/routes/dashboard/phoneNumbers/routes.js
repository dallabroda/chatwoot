import { frontendURL } from '../../../helper/URLHelper';
import PhoneNumbersIndex from './pages/PhoneNumbersIndex.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/phone-numbers'),
    name: 'phone_numbers_index',
    component: PhoneNumbersIndex,
    meta: {
      permissions: ['administrator'],
    },
  },
];
