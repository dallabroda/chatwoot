<script>
import { DEFAULT_REDIRECT_URL } from 'dashboard/constants/globals';
import { verifyPasswordToken } from '../../../api/auth';
import {
  getLoginRedirectURL,
  getMfaSignInURL,
} from '../../../helpers/AuthHelper';
import Spinner from 'shared/components/Spinner.vue';

// Cred Chat: confirm only on an explicit click. Corporate mail scanners (e.g. Microsoft Safe Links)
// open every link in the message, and auto-confirming on page load let them activate accounts.
export default {
  components: { Spinner },
  props: {
    ssoAccountId: { type: String, default: '' },
    confirmationToken: {
      type: String,
      default: '',
    },
    redirectUrl: {
      type: String,
      default: '',
    },
  },
  data() {
    return { isConfirming: false };
  },
  methods: {
    async confirmToken() {
      this.isConfirming = true;
      try {
        const user = await verifyPasswordToken({
          confirmationToken: this.confirmationToken,
        });
        window.location =
          (user?.redirectUrl &&
            getMfaSignInURL({
              loginUrl: user.redirectUrl,
              redirectUrl: this.redirectUrl,
              ssoAccountId: this.ssoAccountId,
            })) ||
          getLoginRedirectURL({
            user,
            ssoAccountId: this.ssoAccountId,
            redirectUrl: this.redirectUrl,
          });
      } catch (error) {
        window.location = DEFAULT_REDIRECT_URL;
      }
    },
  },
};
</script>

<template>
  <div
    class="flex items-center justify-center min-h-screen h-full bg-n-background w-full p-4"
  >
    <div v-if="isConfirming" class="flex items-center">
      <Spinner color-scheme="primary" size="" />
      <div class="ml-2 text-n-slate-11">{{ $t('CONFIRM_EMAIL') }}</div>
    </div>
    <div
      v-else
      class="max-w-sm w-full text-center bg-n-solid-1 rounded-xl outline outline-1 outline-n-container p-8"
    >
      <h1 class="text-xl font-semibold text-n-slate-12">
        {{ $t('CONFIRM_EMAIL_PAGE.TITLE') }}
      </h1>
      <p class="mt-2 text-sm text-n-slate-11">
        {{ $t('CONFIRM_EMAIL_PAGE.DESCRIPTION') }}
      </p>
      <button
        type="button"
        class="mt-6 w-full rounded-lg bg-n-brand px-4 py-2.5 text-sm font-medium text-white hover:opacity-90"
        @click="confirmToken"
      >
        {{ $t('CONFIRM_EMAIL_PAGE.BUTTON') }}
      </button>
    </div>
  </div>
</template>
