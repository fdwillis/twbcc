class BackgroundJob
  include Sidekiq::Job

  # sidekiq_retry_in { 5.minutes.to_i }

  def perform(tvData, krakenLiveAPI, krakenLiveSecret, job)
    if job == "stop"
      Kraken.krakenTrailStop(tvData, krakenLiveAPI, krakenLiveSecret)
    end

    if job == "entry"
      Kraken.krakenLimitOrder(tvData, krakenLiveAPI, krakenLiveSecret)
    end

    if job == "market"
      Kraken.krakenMarketOrder(tvData, krakenLiveAPI, krakenLiveSecret)
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
    "profitBy" => "1",
    "broker" => "kraken",
    "trail" => "0.30"}
  end
end
