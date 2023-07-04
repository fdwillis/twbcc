class BackgroundJob
  include Sidekiq::Job

  def perform(job, tvData, apiKey = nil, secretKey = nil)
    ApplicationRecord.trailStop(tvData, apiKey, secretKey) if job == 'stop'

    ApplicationRecord.newEntry(tvData, apiKey, secretKey) if job == 'entry'

    ApplicationRecord.killPending(tvData, apiKey, secretKey) if job == 'kill'
  end
end
