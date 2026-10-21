/* global axios */

import ApiClient from './ApiClient';

class CustomBillingAPI extends ApiClient {
  constructor() {
    super('custom_billing', { accountScoped: true });
  }

  getSummary() {
    return axios.get(this.url);
  }

  subscribe(payload) {
    return axios.post(`${this.url}/subscribe`, payload);
  }

  updateSlots(totalNumbers) {
    return axios.post(`${this.url}/update_slots`, { total_numbers: totalNumbers });
  }

  updateCard(cardPayload) {
    return axios.post(`${this.url}/update_card`, cardPayload);
  }

  getInvoices() {
    return axios.get(`${this.url}/invoices`);
  }
}

export default new CustomBillingAPI();
