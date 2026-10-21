# Lists the Meta assets (pages, ad accounts, ...) businesses shared during embedded signup,
# resolving each id to a display name with the token of the channel it was shared with.
class Whatsapp::SharedAssetsService
  API_VERSION = 'v22.0'.freeze

  ASSET_TYPES = {
    'pages' => { ids_key: 'page_ids', path: '%s', fields: 'name' },
    'ad_accounts' => { ids_key: 'ad_account_ids', path: 'act_%s', fields: 'name' },
    'datasets' => { ids_key: 'dataset_ids', path: '%s', fields: 'name' },
    'catalogs' => { ids_key: 'catalog_ids', path: '%s', fields: 'name' },
    'instagram_accounts' => { ids_key: 'instagram_account_ids', path: '%s', fields: 'username,name' }
  }.freeze

  def initialize(account)
    @account = account
  end

  def perform
    ASSET_TYPES.keys.index_with { |type| assets_of(type) }
  end

  private

  def assets_of(type)
    config = ASSET_TYPES.fetch(type)
    channels.flat_map do |channel|
      Array(channel.provider_config.dig('shared_assets', config[:ids_key])).map do |id|
        fetch_asset(channel, format(config[:path], id), config[:fields]).merge(id: id, phone_number: channel.phone_number)
      end
    end
  end

  def channels
    @channels ||= Channel::Whatsapp.where(account: @account, provider: 'whatsapp_cloud')
                                   .select { |channel| channel.provider_config['shared_assets'].present? }
  end

  def fetch_asset(channel, path, fields)
    response = HTTParty.get("#{base_url}/#{API_VERSION}/#{path}", headers: channel.api_headers, query: { fields: fields })
    return { name: nil, error: Whatsapp::MetaApiError.from_response(response).message } unless response.success?

    { name: response['name'] || response['username'], username: response['username'] }
  end

  def base_url
    ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end
end
