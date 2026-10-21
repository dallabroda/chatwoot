/* global axios */
import CacheEnabledApiClient from './CacheEnabledApiClient';

class Inboxes extends CacheEnabledApiClient {
  constructor() {
    super('inboxes', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'inbox';
  }

  getCampaigns(inboxId) {
    return axios.get(`${this.url}/${inboxId}/campaigns`);
  }

  deleteInboxAvatar(inboxId) {
    return axios.delete(`${this.url}/${inboxId}/avatar`);
  }

  getAgentBot(inboxId) {
    return axios.get(`${this.url}/${inboxId}/agent_bot`);
  }

  setAgentBot(inboxId, botId) {
    return axios.post(`${this.url}/${inboxId}/set_agent_bot`, {
      agent_bot: botId,
    });
  }

  syncTemplates(inboxId) {
    return axios.post(`${this.url}/${inboxId}/sync_templates`);
  }

  createWhatsappTemplate(inboxId, payload) {
    return axios.post(`${this.url}/${inboxId}/whatsapp_templates`, payload);
  }

  requestWhatsappVerificationCode(inboxId, codeMethod) {
    return axios.post(
      `${this.url}/${inboxId}/whatsapp_phone_number/request_code`,
      { code_method: codeMethod }
    );
  }

  verifyWhatsappCode(inboxId, code) {
    return axios.post(
      `${this.url}/${inboxId}/whatsapp_phone_number/verify_code`,
      { code }
    );
  }

  registerWhatsappNumber(inboxId, pin) {
    return axios.post(`${this.url}/${inboxId}/whatsapp_phone_number/register`, {
      pin,
    });
  }

  deregisterWhatsappNumber(inboxId) {
    return axios.post(
      `${this.url}/${inboxId}/whatsapp_phone_number/deregister`
    );
  }

  updateWhatsappTemplate(inboxId, templateId, payload) {
    return axios.patch(
      `${this.url}/${inboxId}/whatsapp_templates/${templateId}`,
      payload
    );
  }

  deleteWhatsappTemplate(inboxId, templateId, name) {
    return axios.delete(
      `${this.url}/${inboxId}/whatsapp_templates/${templateId}`,
      { params: { name } }
    );
  }

  uploadWhatsappTemplateHeaderMedia(inboxId, file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(
      `${this.url}/${inboxId}/whatsapp_templates/header_media`,
      formData
    );
  }

  getMessageTemplates(inboxId, params = {}, config = {}) {
    return axios.get(`${this.url}/${inboxId}/message_templates`, {
      ...config,
      params,
    });
  }

  updateWhatsappBusinessManagementToken(inboxId, businessManagementToken) {
    return axios.put(
      `${this.url}/${inboxId}/whatsapp_business_management_token`,
      {
        business_management_token: businessManagementToken,
      }
    );
  }

  createCSATTemplate(inboxId, template) {
    return axios.post(`${this.url}/${inboxId}/csat_template`, {
      template,
    });
  }

  getCSATTemplateStatus(inboxId) {
    return axios.get(`${this.url}/${inboxId}/csat_template`);
  }

  analyzeCSATTemplateUtility(inboxId, template) {
    return axios.post(`${this.url}/${inboxId}/csat_template/analyze`, {
      template,
    });
  }

  resetSecret(inboxId) {
    return axios.post(`${this.url}/${inboxId}/reset_secret`);
  }

  rotateHmacToken(inboxId) {
    return axios.post(`${this.url}/${inboxId}/rotate_hmac_token`);
  }

  enableWhatsappCalling(inboxId) {
    return axios.post(`${this.url}/${inboxId}/enable_whatsapp_calling`);
  }

  disableWhatsappCalling(inboxId) {
    return axios.post(`${this.url}/${inboxId}/disable_whatsapp_calling`);
  }

  setInboundCalls(inboxId, enabled) {
    return axios.post(`${this.url}/${inboxId}/set_inbound_calls`, {
      inbound_calls_enabled: enabled,
    });
  }

  setCallRecording(inboxId, { recordingEnabled, transcriptionEnabled }) {
    return axios.post(`${this.url}/${inboxId}/set_call_recording`, {
      recording_enabled: recordingEnabled,
      transcription_enabled: transcriptionEnabled,
    });
  }
}

export default new Inboxes();
