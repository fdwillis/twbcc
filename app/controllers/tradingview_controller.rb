class TradingviewController < ApplicationController
	protect_from_forgery with: :null_session

	def signals

		case true
		when params['ticker'] == "BTCUSD"

			case true
			when params['type'] == 'sellStop' || params['type'] == 'buyStop'
				trailOrStop = Crypto.createTrailOrStopOrder(params)
				# debugger
			when params['type'] == 'entry'
				marketOrder = Crypto.createMarketOrder(params)
				limitOrder = Crypto.createLimitOrder(params)
			when params['type'].include?('profit')
			end

			render json: {success: true}
		when params['ticker'] == "EURUSD"			
		end
	end
end