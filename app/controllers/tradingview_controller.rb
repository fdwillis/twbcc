class TradingviewController < ApplicationController
	protect_from_forgery with: :null_session

	def signals

		case true
		when params['ticker'] == "BTCUSD"

			case true
			when params['type'] == 'buyStop'
			when params['type'] == 'sellStop'
			when params['type'] == 'newBuy'
				Crypto.createMarketOrder(params)
				# Crypto.createLimitOrder(params)
			when params['type'] == 'newSell'
			when params['type'] == 'profit1'
			when params['type'] == 'profit2'
			when params['type'] == 'profit3'
			end

			render json: {success: true}
		when params['ticker'] == "EURUSD"			
		end
	end
end