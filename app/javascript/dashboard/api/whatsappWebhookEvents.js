import ApiClient from './ApiClient';

class WhatsappWebhookEventsAPI extends ApiClient {
  constructor() {
    super('whatsapp_webhook_events', { accountScoped: true });
  }
}

export default new WhatsappWebhookEventsAPI();
