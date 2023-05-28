class TradingviewController < ApplicationController
	protect_from_forgery with: :null_session

	def signals

		case true
		when params['ticker'] == "BTCUSD"

			case true
			when params['type'].include?('Stop')
				trailOrStop = Crypto.createTrailOrStopOrder(params)
				puts trailOrStop
			when params['type'] == 'entry'
				# marketOrder = Crypto.krakenMarketOrder(params)
				limitOrder = Crypto.krakenLimitOrder(params)
				puts limitOrder
			when params['type'].include?('profit')
			end

			render json: {success: true}
		when params['ticker'] == "EURUSD"			
		end
	end
end