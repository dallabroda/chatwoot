import ApiClient from './ApiClient';

class WhatsappSharedAssetsAPI extends ApiClient {
  constructor() {
    super('whatsapp_shared_assets', { accountScoped: true });
  }
}

export default new WhatsappSharedAssetsAPI();
