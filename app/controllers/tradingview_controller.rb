class TradingviewController < ApplicationController
	protect_from_forgery with: :null_session

	def signals

		case true
		when params['ticker'] == "BTCUSD"

			case true
			when params['type'].include?('Stop')
				trailOrStop = Crypto.createTrailOrStopOrder(params)
			when params['type'] == 'entry' &&  params['direction'] == 'buy'
				marketOrder = Crypto.krakenMarketOrder(params)
				limitOrder = Crypto.krakenLimitOrder(params)
			when params['type'].include?('profit')
			end

			render json: {success: true}
		when params['ticker'] == "EURUSD"			
		end
	end
end