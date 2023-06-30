class TradingviewController < ApplicationController
	protect_from_forgery with: :null_session

	def manage_trading_keys
		if params['editKeys'] && autoTradingKeysparams.present?
			current_user.update(autoTradingKeysparams)
			flash[:success] = "Keys Updated"
			redirect_to request.referrer
			return
		elsif params['authorizedList'] && authorizedListParams.present?
			current_user.update(authorizedListParams)
			flash[:success] = "Authorized List Updated"
			redirect_to request.referrer
			return
		else
			flash[:notice] = "Cannot Be Blank"
			redirect_to request.referrer
			return
		end
	end

	def signals
		traderID = params['traderID']
		traderFound = User.find_by(uuid: traderID)
		if params['tradingDays'].present? && params['tradingDays'].map{|d| d.downcase}.include?(Date.today.strftime('%a').downcase)
			if traderFound.trader?
				
				if Oj.load(ENV['adminUUID']).include?(traderFound.uuid)
					if params['tradeForAdmin'] == 'true'
						case true
						when params['type'].include?('Stop')
							case true
							when params['broker'] == 'KRAKEN'
								BackgroundJob.perform_async('stop',tradingviewKeysparams.to_h, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret)
							when params['broker'] == 'OANDA'
								traderFound.oandaList.split(",").each do |accountID|
									BackgroundJob.perform_async('stop',tradingviewKeysparams.to_h, traderFound.oandaToken, accountID)
								end
							end
						when params['type'] == 'entry'
							case true
							when params['broker'] == 'KRAKEN'
								BackgroundJob.perform_async('entry',tradingviewKeysparams.to_h, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret)
							when params['broker'] == 'OANDA'
								traderFound.oandaList.split(",").each do |accountID|
									BackgroundJob.perform_async('entry',tradingviewKeysparams.to_h, traderFound.oandaToken, accountID)
								end
							end
						when params['type'].include?('profit')
						end
					elsif  params['adminOnly'] == 'false'
						puts "\n-- Starting To Copy Trades --\n"
						#pull those with done for you plan
						monthlyAuto = Stripe::Subscription.list({limit: 100, price: ENV['autoTradingMonthlyMembership']})['data'].reject{|d| d['status'] != 'active'}
						annualAuto = Stripe::Subscription.list({limit: 100, price: ENV['autoTradingAnnualMembership']})['data'].reject{|d| d['status'] != 'active'}

						validPlansToParse = monthlyAuto + annualAuto

						validPlansToParse.each do |planXinfo|
							traderFoundForCopy = User.find_by(stripeCustomerID: planXinfo['customer'])
							listToTrade = traderFoundForCopy.authorizedList.delete(' ').split(",").reject(&:blank?)
							if !traderFoundForCopy.admin?
								puts "\n-- Started For #{traderFoundForCopy.uuid} --\n"
								listToTrade.each do |assetX|
									if assetX.upcase == params['ticker']
										# execute trade
										case true
										when params['type'].include?('Stop')
											case true
											when params['broker'] == 'KRAKEN'
												BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFoundForCopy.krakenLiveAPI, traderFoundForCopy.krakenLiveSecret)
											when params['broker'] == 'OANDA'
												traderFound.oandaList.split(",").each do |accountID|
													BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFoundForCopy.oandaToken, accountID)
												end
											end
										when params['type'] == 'entry'
											case true
											when params['broker'] == 'KRAKEN'
												BackgroundJob.perform_async('entry', tradingviewKeysparams.to_h, traderFoundForCopy.krakenLiveAPI, traderFoundForCopy.krakenLiveSecret)
											when params['broker'] == 'OANDA'
												traderFound.oandaList.split(",").each do |accountID|
													BackgroundJob.perform_async('entry', tradingviewKeysparams.to_h, traderFoundForCopy.oandaToken, accountID)
												end
											end
										when params['type'].include?('profit')
										end
									end
								end
							end
						end
					end

					puts "\n-- Finished Copying Trades --\n"
				else
					case true
					when params['type'].include?('Stop')
						case true
						when params['broker'] == 'KRAKEN'
							BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret)
						when params['broker'] == 'OANDA'
							BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFound.oandaToken, nil)
						end
					when params['type'] == 'entry'
						case true
						when params['broker'] == 'KRAKEN'
							BackgroundJob.perform_async('entry',tradingviewKeysparams.to_h, traderFound.krakenLiveAPI, traderFound.krakenLiveSecret)
						when params['broker'] == 'OANDA'
							BackgroundJob.perform_async('entry', tradingviewKeysparams.to_h, traderFound.oandaToken, nil)
						end
					when params['type'].include?('profit')
					end
				end

				render json: {success: true}
			else
				puts "\n-- No Trader Found --\n"
			end
		else
			puts "\n-- No Trading Today--\n"
		end

		Sidekiq.redis(&:flushdb)
	end

	private

	def autoTradingKeysparams
    params.require(:editKeys).permit(:krakenLiveAPI, :krakenLiveSecret, :krakenTestAPI, :krakenTestSecret, :oandaToken, :oandaList)
  end

  def authorizedListParams
    params.require(:authorizedList).permit(:authorizedList)
  end

  def tradingviewKeysparams
    params.permit(:adminOnly, :tradeForAdmin, :ticker, :tickerType, :type, :direction, :timeframe, :currentPrice, :highPrice, :tradingview, :traderID, :lowPrice, :broker, :allowMarketOrder, :profitTrigger, :maxRisk, :maxProfit, :reduceBy, :trail, :perEntry, :entries => [], :tradingDays => [])
  end
end

