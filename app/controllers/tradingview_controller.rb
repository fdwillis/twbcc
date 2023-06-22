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
			if traderFound.trader?
				case true
				when params['broker'] == "kraken"

					case true
					when params['type'].include?('Stop')
						BackgroundJob.perform_async(tradingviewKeysparams.to_h, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret, 'stop')
					when params['type'] == 'entry'
						if params['allowMarketOrder'] == 'true'
							BackgroundJob.perform_async(tradingviewKeysparams.to_h, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret, 'market')
						end

						BackgroundJob.perform_async(tradingviewKeysparams.to_h, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret, 'limit')
						

					when params['type'].include?('profit')
					end

					render json: {success: true}
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
    params.permit(:ticker, :tickerType, :type, :direction, :timeframe, :currentPrice, :highPrice, :tradingview, :traderID, :lowPrice, :broker, :allowMarketOrder, :profitTrigger, :maxRisk, :maxProfit, :reduceBy, :trail, :perEntry, :entries => [], :tradingDays => [])
  end
end

