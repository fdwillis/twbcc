Split.configure do |config|
  config.db_failover = true # handle Redis errors gracefully
  config.db_failover_on_db_error = -> (error) { Rails.logger.error(error.message) }
  config.enabled = true
  #config.start_manually = false ## new test will have to be started manually from the admin panel. default false
  #config.reset_manually = false ## if true, it never resets the experiment data, even if the configuration changes
  config.include_rails_helper = true
  config.redis = Redis.new
  config.persistence = :cookie
  config.persistence_cookie_length = 7776000 # 90 days
end