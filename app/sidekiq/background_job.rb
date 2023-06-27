class BackgroundJob
  include Sidekiq::Job

  def perform(tvData, apiKey, secretKey, job)
    if job == "stop"
      ApplicationRecord.trailStop(tvData, apiKey, secretKey)
    end
    
    if job == "entry"
      ApplicationRecord.newEntry(tvData, apiKey, secretKey)
    end

  end
end
