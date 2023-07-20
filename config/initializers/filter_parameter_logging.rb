# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += %i[krakenLiveAPI krakenLiveSecret uuid password_confirmation sequence email phone password referredBy session tradingview traderID]
