class Webhooks::EvolutionController < ActionController::API
  def process_payload
    Webhooks::EvolutionEventsJob.perform_later(instance_name: params[:instance_name], params: params.to_unsafe_hash)
    head :ok
  end
end
