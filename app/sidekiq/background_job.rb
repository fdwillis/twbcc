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

    allTrades = Trade.all

    if allTrades.present? && allTrades.size > 0 
      allTrades.each do |trade|
        traderFound = User.find(trade&.user_id)
        case true
        when trade&.broker == 'KRAKEN'
          requestK = Kraken.orderInfo(trade.uuid, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret)
          trade.update(status: requestK['status'])
          if trade.status == 'canceled'
            trade.destroy
          end
        when trade&.broker == 'OANDA'
          traderFound&.oandaList&.split(",")&.reject(&:blank?).each do |accountID|
            requestK = Oanda.oandaOrder(traderFound.oandaToken, accountID, trade.uuid)
          end

          if requestK['order']['state'] == "CANCELLED"
            if trade.status == 'canceled'
              trade.destroy
            end
          end

          if requestK['order']['state'] == "FILLED"
            trade.update(status: 'closed')
          end
        end
      end
    end

  end
end
