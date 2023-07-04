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
        case true
        when trade&.broker == 'KRAKEN'
          requestK = Kraken.orderInfo(trade.uuid, apiKey, secretKey)
          trade.update(status: requestK['status'])
          if trade.status == 'canceled'
            trade.destroy
          end
        when trade&.broker == 'OANDA'
            requestK = Oanda.oandaOrder(oandaToken, apiKey, trade.uuid)

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
