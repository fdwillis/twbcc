class TradingviewController < ApplicationController
	protect_from_forgery with: :null_session

	def win_rate
		#pull all closed trades -> build result to display
		#pull all open trades -> build result to display
		cryptoAssets = 0
		forexAssets = 0
		stocksAssets = 0
		optionsAssets = 0
		@currentTrades = Trade.all.where(finalTakeProfit: nil)&.size
		@entriesTrades = Trade.all.size
		@exitsTrades = Trade.all.where.not(finalTakeProfit: nil)&.size
		@profitTotal = 0
		@costTotal = 0

		User.all.each do |user|
			#assets under management (tally together crypto, forex, stocks, options)
			if user&.oandaToken.present? && user&.oandaList.present?
				oandaAccounts = user&.oandaList.split(',')
				oandaAccounts.each do |accountID|
					oandaX = Oanda.oandaRequest(user&.oandaToken, accountID)
					balanceX = Oanda.oandaBalance(user&.oandaToken, accountID)
					forexAssets += balanceX
				end
			end

			if user&.krakenLiveAPI.present? && user&.krakenLiveSecret.present?
				balanceX = Kraken.krakenBalance(user&.krakenLiveAPI, user&.krakenLiveSecret)
				krakenResult = balanceX['result'].reject{|d,f| f.to_f == 0}
				baseCurrency = krakenResult.reject{|d, f| !d.include?("Z")}.keys[0]

				krakenResult.each do |resultX|
					baseTicker = resultX[0]
					assetInfo = Kraken.assetInfo({'ticker' => baseTicker},  user&.krakenLiveAPI, user&.krakenLiveSecret)
					tradeBalanceCall = Kraken.tradeBalance(baseTicker, user&.krakenLiveAPI, user&.krakenLiveSecret)
					units = balanceX['result'][baseTicker].to_f
					altName = assetInfo['result'][baseTicker]['altname']
					tickerInfo = Kraken.tickerInfo({'ticker' => "#{altName}#{baseCurrency.delete("Z")}"}, user&.krakenLiveAPI, user&.krakenLiveSecret)

					if resultX[0] == "ZUSD"
						cryptoAssets += krakenResult['ZUSD'].to_f
					else

						ask = tickerInfo['result']["#{baseTicker}#{baseCurrency}"]['a'][0].to_f
						bid = tickerInfo['result']["#{baseTicker}#{baseCurrency}"]['b'][0].to_f

						averagePrice = (ask + bid)/2

						risked = averagePrice * units
						cryptoAssets += risked
					end
				end
			end
		end

		@assetsUM = cryptoAssets + forexAssets + stocksAssets + optionsAssets
	end

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
		elsif profitTriggersparams.present?
			current_user.update(profitTriggersparams)
			flash[:success] = "Profit Triggers & Risk Tolerance Updated"
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
							listToTrade = traderFoundForCopy&.authorizedList&.delete(' ')
							if traderFoundForCopy.trader? && !listToTrade.blank?
								puts "\n-- Started For #{traderFoundForCopy.uuid} --\n"
								listToTrade.split(",")&.reject(&:blank?).each do |assetX|
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
									elsif (current_user&.authorizedList == 'crypto' ? "BTC#{ISO3166::Country[current_user.amazonCountry.downcase].currency_code}" : current_user&.authorizedList == 'forex' ? "EUR#{ISO3166::Country[current_user.amazonCountry.downcase].currency_code}" : nil )
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
    params.permit(:adminOnly, :tradeForAdmin, :ticker, :tickerType, :type, :direction, :timeframe, :currentPrice, :highPrice, :tradingview, :traderID, :lowPrice, :broker, :trail, :entries => [], :tradingDays => [])
  end

  def profitTriggersparams
    params.require(:profitTriggers).permit(:perEntry,:reduceBy,:profitTrigger,:maxRisk,:allowMarketOrder)
  end
end

