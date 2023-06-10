class BackgroundJob
  include Sidekiq::Job

  sidekiq_retry_in { 5.minutes.to_i }

  def perform(tvData, currentUser)
    Kraken.krakenTrailStop(tvData, currentUser)
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
    "profitBy" => "1",
    "broker" => "kraken",
    "trail" => "0.30"}
  end
end
