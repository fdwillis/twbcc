class BackgroundJob
  include Sidekiq::Job

  # sidekiq_retry_in { 1.minutes.to_i }

  def perform(tvData, apiKey, secretKey, job)
    if job == "stop"
      ApplicationRecord.trailStop(tvData, apiKey, secretKey)
    end
    
    if job == "market"
      ApplicationRecord.marketOrder(tvData, apiKey, secretKey)
    end

    if job == "limit"
      ApplicationRecord.limitOrder(tvData, apiKey, secretKey)
    end

  end
end
