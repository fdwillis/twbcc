class BackgroundJob
  include Sidekiq::Job

  sidekiq_retry_in { 5.minutes.to_i }

  def trail(tvData, currentUser)
    Kraken.krakenTrailStop(tvData, currentUser)
  end

  def market(tvData, currentUser)
    Kraken.krakenMarketOrder(tvData, currentUser)
  end

  def limit(tvData, currentUser)
    Kraken.krakenLimitOrder(tvData, currentUser)
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
