class TradingviewController < ApplicationController
	protect_from_forgery with: :null_session

	def manage_trading_keys
		if autoTradingKeysparams.present?
			current_user.update(autoTradingKeysparams)
			flash[:success] = "Keys Updated"
			redirect_to request.referrer
			return
		else
			flash[:notice] = "Cannot Be Blank"
			redirect_to request.referrer
			return
		end
	end

	def signals
		# check user exists from uuid
		# if user subscription is active -> continue
		traderID = params['traderID']
		traderFound = User.find_by(uuid: traderID)
		if params['tradingDays'].present? && params['tradingDays'].map{|d| d.downcase}.include?(Date.today.strftime('%a').downcase)
			if traderID.present? && traderFound && traderFound.trader?
				case true
				when params['tickerType'] == "crypto"

					case true
					when params['type'].include?('Stop')
						BackgroundJob.perform_async(tradingviewKeysparams.to_h, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret, 'stop')
						# Kraken.krakenTrailStop(params, traderFound)
					when params['type'] == 'entry'
						if params['allowMarketOrder'] == 'true'
							BackgroundJob.perform_async(tradingviewKeysparams.to_h, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret, 'market')
							# marketOrder = Kraken.krakenMarketOrder(params, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret)
						end

						BackgroundJob.perform_async(tradingviewKeysparams.to_h, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret, 'entry')
						# limitOrder = Kraken.krakenLimitOrder(params, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret)
						

					when params['type'].include?('profit')
					end

					render json: {success: true}
				when params['tickerType'] == "forex"	
				# build for oanda 
				end
			else
				puts "\n-- No Trader Found --\n"
			end
		else
			puts "\n-- No Trading Today--\n"
		end
	end

	private

	def autoTradingKeysparams
    params.require(:editKeys).permit(:krakenLiveAPI, :krakenLiveSecret, :krakenTestAPI, :krakenTestSecret)
  end

  def tradingviewKeysparams
    params.permit(:ticker, :tickerType, :type, :direction, :timeframe, :currentPrice, :highPrice, :tradingview, :traderID, :lowPrice, :broker, :allowMarketOrder, :profitBy, :maxRisk, :perEntry, :entries => [])
  end
end

