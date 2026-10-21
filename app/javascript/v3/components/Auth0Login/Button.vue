<script setup>
import { computed } from 'vue';

const props = defineProps({
  ssoAccountId: { type: String, default: '' },
  redirectUrl: { type: String, default: '' },
});

// Built by hand like the Google button: devise-token-auth cannot redirect the
// POST request phase (lynndylanhurley/devise_token_auth#1466), so the callback
// runs with provider_ignores_state and reads redirect hints from `state`.
const authorizeUrl = computed(() => {
  const { auth0Domain, auth0ClientId, hostURL } = window.chatwootConfig;
  const query = {
    client_id: auth0ClientId,
    redirect_uri: `${hostURL}/omniauth/auth0/callback`,
    response_type: 'code',
    scope: 'openid email profile',
  };
  if (props.redirectUrl) query.state = props.redirectUrl;
  if (props.ssoAccountId) {
    query.state = JSON.stringify({
      redirect_url: props.redirectUrl,
      sso_account_id: props.ssoAccountId,
    });
  }
  return `https://${auth0Domain}/authorize?${new URLSearchParams(query)}`;
});
</script>

<template>
  <a
    :href="authorizeUrl"
    class="inline-flex justify-center w-full px-4 py-3 bg-n-background dark:bg-n-solid-3 items-center rounded-md shadow-sm ring-1 ring-inset ring-n-container dark:ring-n-container focus:outline-offset-0 hover:bg-n-alpha-2 dark:hover:bg-n-alpha-2"
  >
    <span class="i-lucide-log-in size-5 text-n-slate-11" />
    <span class="ml-2 text-base font-medium text-n-slate-12">
      {{ $t('LOGIN.OAUTH.CREDTECH_LOGIN') }}
    </span>
  </a>
</template>
