class TradingviewController < ApplicationController
	protect_from_forgery with: :null_session

	def signals
		# check user exists from uuid
		# if user subscription is active -> continue

		case true
		when params['tickerType'] == "crypto"

			case true
			when params['type'].include?('Stop')
				# BackgroundJob.perform_async(params)
				Kraken.krakenTrailStop(params)
			when params['type'] == 'entry'
				limitOrder = Kraken.krakenLimitOrder(params)
				
				if params['allowMarketOrder'] == 'true'
					marketOrder = Kraken.krakenMarketOrder(params)
				end

			when params['type'].include?('profit')
			end

			render json: {success: true}
		when params['tickerType'] == "forex"	
		# build for oanda 
		end
	end
end

