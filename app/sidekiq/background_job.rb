class BackgroundJob
  include Sidekiq::Job

  def perform(job,tvData, apiKey = nil, secretKey = nil)
    if job == "stop"
      ApplicationRecord.trailStop(tvData, apiKey, secretKey)
    end
    
    if job == "entry"
      ApplicationRecord.newEntry(tvData, apiKey, secretKey)
    end

    if job == "kill"
      ApplicationRecord.killPending(tvData, apiKey, secretKey)
    end
  end
end
