/* global axios */

import ApiClient from './ApiClient';

class WhatsappEvolutionConnectionsAPI extends ApiClient {
  constructor() {
    super('whatsapp_evolution_connections', { accountScoped: true });
  }

  qr(inboxId) {
    return axios.get(`${this.url}/${inboxId}/qr`);
  }

  status(inboxId) {
    return axios.get(`${this.url}/${inboxId}/status`);
  }
}

export default new WhatsappEvolutionConnectionsAPI();
