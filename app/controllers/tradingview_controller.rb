class TradingviewController < ApplicationController
	protect_from_forgery with: :null_session

	def signals

		case true
		when params['tickerType'] == "crypto"

			case true
			when params['type'].include?('Stop')
<<<<<<< Updated upstream
				trailOrStop = Kraken.krakenTrailStop(params)
=======
				dataSaved = JsonDatum.create(payload: params)
				BackgroundJob.perform_async(dataSaved[:payload])
>>>>>>> Stashed changes
			when params['type'] == 'entry'
				
				if params['allowMarketOrder'] == 'true'
					marketOrder = Kraken.krakenMarketOrder(params)
				end

				limitOrder = Kraken.krakenLimitOrder(params)
			when params['type'].include?('profit')
			end

			render json: {success: true}
		when params['ticker'] == "EURUSD"			
		end
	end
end

