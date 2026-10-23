<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import FormInput from '../../../components/Form/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PasswordRequirements from '../signup/components/Signup/PasswordRequirements.vue';
import { DEFAULT_REDIRECT_URL } from 'dashboard/constants/globals';
import { isValidPassword } from 'shared/helpers/Validators';
import { setNewPassword } from '../../../api/auth';
import { getLoginRedirectURL, getMfaSignInURL } from 'v3/helpers/AuthHelper';

export default {
  components: {
    FormInput,
    NextButton,
    PasswordRequirements,
  },
  props: {
    resetPasswordToken: { type: String, default: '' },
    redirectUrl: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        confirmPassword: '',
        password: '',
      },
      newPasswordAPI: {
        message: '',
        showLoading: false,
      },
      error: '',
      // Cred Chat: links are single-use and each new email voids the previous one
      isInvalidLink: false,
    };
  },
  mounted() {
    // If url opened without token
    // redirect to login
    if (!this.resetPasswordToken) {
      window.location = DEFAULT_REDIRECT_URL;
    }
  },
  validations: {
    credentials: {
      password: {
        required,
        minLength: minLength(6),
        isValidPassword,
      },
      confirmPassword: {
        required,
        minLength: minLength(6),
        isEqPassword(value) {
          if (value !== this.credentials.password) {
            return false;
          }
          return true;
        },
      },
    },
  },
  methods: {
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.newPasswordAPI.showLoading = false;
      useAlert(message);
    },
    submitForm() {
      this.newPasswordAPI.showLoading = true;
      this.error = '';
      const credentials = {
        confirmPassword: this.credentials.confirmPassword,
        password: this.credentials.password,
        resetPasswordToken: this.resetPasswordToken,
      };
      setNewPassword(credentials)
        .then(user => {
          window.location =
            (user?.redirectUrl &&
              getMfaSignInURL({
                loginUrl: user.redirectUrl,
                redirectUrl: this.redirectUrl,
                ssoAccountId: this.ssoAccountId,
              })) ||
            (this.redirectUrl
              ? getLoginRedirectURL({
                  redirectUrl: this.redirectUrl,
                  ssoAccountId: this.ssoAccountId,
                  user,
                })
              : DEFAULT_REDIRECT_URL);
        })
        .catch(error => {
          this.newPasswordAPI.showLoading = false;
          if (error?.code === 'invalid_token') {
            this.isInvalidLink = true;
            return;
          }
          this.error =
            error?.message || this.$t('SET_NEW_PASSWORD.API.ERROR_MESSAGE');
        });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col justify-center w-full min-h-screen py-12 bg-n-brand/5 dark:bg-n-background sm:px-6 lg:px-8"
  >
    <div
      v-if="isInvalidLink"
      role="alert"
      class="bg-white shadow sm:mx-auto sm:w-full sm:max-w-lg dark:bg-n-solid-2 p-11 sm:shadow-lg sm:rounded-lg"
    >
      <h1 class="mb-2 text-2xl font-medium tracking-tight text-n-slate-12">
        {{ $t('SET_NEW_PASSWORD.INVALID_LINK.TITLE') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ $t('SET_NEW_PASSWORD.INVALID_LINK.DESCRIPTION') }}
      </p>
      <router-link
        :to="{
          name: 'auth_reset_password',
          query: { sso_account_id: ssoAccountId || undefined },
        }"
        class="mt-6 inline-flex w-full justify-center rounded-lg bg-n-brand px-4 py-2.5 text-sm font-medium text-white hover:opacity-90"
      >
        {{ $t('SET_NEW_PASSWORD.INVALID_LINK.ACTION') }}
      </router-link>
    </div>
    <form
      v-else
      class="bg-white shadow sm:mx-auto sm:w-full sm:max-w-lg dark:bg-n-solid-2 p-11 sm:shadow-lg sm:rounded-lg"
      @submit.prevent="submitForm"
    >
      <h1
        class="mb-1 text-2xl font-medium tracking-tight text-left text-n-slate-12"
      >
        {{ $t('SET_NEW_PASSWORD.TITLE') }}
      </h1>

      <div class="space-y-5">
        <div>
          <FormInput
            v-model="credentials.password"
            class="mt-3"
            name="password"
            type="password"
            :has-error="v$.credentials.password.$error"
            :error-message="$t('SET_NEW_PASSWORD.PASSWORD.ERROR')"
            :placeholder="$t('SET_NEW_PASSWORD.PASSWORD.PLACEHOLDER')"
            @blur="v$.credentials.password.$touch"
          />
          <p class="mt-3 mb-1 text-xs font-medium text-n-slate-11">
            {{ $t('SET_NEW_PASSWORD.RULES_TITLE') }}
          </p>
          <PasswordRequirements :password="credentials.password" />
        </div>
        <FormInput
          v-model="credentials.confirmPassword"
          class="mt-3"
          name="confirm_password"
          type="password"
          :has-error="v$.credentials.confirmPassword.$error"
          :error-message="$t('SET_NEW_PASSWORD.CONFIRM_PASSWORD.ERROR')"
          :placeholder="$t('SET_NEW_PASSWORD.CONFIRM_PASSWORD.PLACEHOLDER')"
          @blur="v$.credentials.confirmPassword.$touch"
        />
        <div
          v-if="error"
          role="alert"
          class="rounded-lg bg-n-ruby-3 px-3 py-2.5 text-sm text-n-ruby-11"
        >
          {{ error }}
        </div>
        <NextButton
          lg
          type="submit"
          data-testid="submit_button"
          class="w-full"
          :label="$t('SET_NEW_PASSWORD.SUBMIT')"
          :disabled="
            v$.credentials.password.$invalid ||
            v$.credentials.confirmPassword.$invalid ||
            newPasswordAPI.showLoading
          "
          :is-loading="newPasswordAPI.showLoading"
        />
      </div>
    </form>
  </div>
</template>
