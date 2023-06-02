class TradingviewController < ApplicationController
	protect_from_forgery with: :null_session

	def signals

		case true
		when params['tickerType'] == "crypto"

			case true
			when params['type'].include?('Stop')
				trailOrStop = Crypto.krakenTrailStop(params)
			when params['type'] == 'entry'
				
				if params['allowMarketOrder'] == 'true'
					marketOrder = Crypto.krakenMarketOrder(params)
				end

				limitOrder = Crypto.krakenLimitOrder(params)
			when params['type'].include?('profit')
			end

			render json: {success: true}
		when params['ticker'] == "EURUSD"			
		end
	end
end