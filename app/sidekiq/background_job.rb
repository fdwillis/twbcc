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

  def self.testParams
    {"ticker" => "BTCUSD",
    "tickerType" => "crypto",
    "type" => "buyStop",
    "direction" => "sell",
    "timeframe" => "15",
    "currentPrice" => "27200",
    "highPrice" => "27230",
    "lowPrice" => "27100",
    "profitTrigger" => "1",
    "maxProfit" => "10",
    "broker" => "kraken",
    "trail" => "0.30"}
  end
end
