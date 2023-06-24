class BackgroundJob
  include Sidekiq::Job

  def perform(tvData, apiKey = nil, secretKey = nil, job)
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
