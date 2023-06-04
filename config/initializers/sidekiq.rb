
Sidekiq.strict_args!(false)
Sidekiq.configure_client do |config|
 config.redis = {db: 10}
end

Sidekiq.configure_server do |config|
 config.redis = {db: 10}
end