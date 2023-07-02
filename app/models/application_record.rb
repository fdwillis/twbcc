class ApplicationRecord < ActiveRecord::Base
	self.abstract_class = true

	def self.trailStop(tvData, apiKey = nil, secretKey = nil)
		puts "\n-- Current Price: #{tvData['currentPrice'].to_f} --\n"

		# pull bot trades
		case true
		when tvData['broker'] == 'KRAKEN'
			openTrades = User.find_by(krakenLiveAPI: apiKey).trades.where(status: 'open', broker: tvData['broker'])
			traderFound = User.find_by(krakenLiveAPI: apiKey)
		when tvData['broker'] == 'OANDA'
			openTrades = User.find_by(oandaToken: apiKey).trades.where(status: 'open', broker: tvData['broker'])
			traderFound = User.find_by(oandaToken: apiKey)
		end


		# update trade status
		if openTrades.present? && openTrades.size > 0 
	  	openTrades.each do |trade|
	  		case true
				when tvData['broker'] == 'KRAKEN'
		  		requestK = Kraken.orderInfo(trade.uuid, apiKey, secretKey)
		  		trade.update(status: requestK['status'])
		  		if trade.status == 'canceled'
		  			trade.destroy
			  	end
				when tvData['broker'] == 'OANDA'
					requestK = Oanda.oandaOrder(apiKey, secretKey, trade.uuid)

					if requestK['order']['state'] == "CANCELLED"
			  		if trade.status == 'canceled'
			  			trade.destroy
				  	end
			  	end

			  	if requestK['order']['state'] == "FILLED"
			  		trade.update(status: 'closed')
			  	end
				end
	  	end
  	end
  	# pull closed/filled bot trades
  	case true
		when tvData['broker'] == 'KRAKEN'
	  	afterUpdates = User.find_by(krakenLiveAPI: apiKey).trades.where(status: 'closed', broker: tvData['broker'], finalTakeProfit: nil)
		when tvData['broker'] == 'OANDA'
	  	afterUpdates = User.find_by(oandaToken: apiKey).trades.where(status: 'closed', broker: tvData['broker'], finalTakeProfit: nil)
		end

  	# protect closed/filled bot trades
  	if afterUpdates.present? && afterUpdates.size > 0	
	  	afterUpdates.each do |tradeX|
			  
	    	case true
				when tvData['broker'] == 'KRAKEN'	
		  		requestOriginalE = Kraken.orderInfo(tradeX.uuid, apiKey, secretKey)
		  		originalPrice = requestOriginalE['price'].to_f
		  		originalVolume = requestOriginalE['vol'].to_f
				when tvData['broker'] == 'OANDA'	
			  	requestExecution = Oanda.oandaOrder(apiKey, secretKey, tradeX.uuid)
					if requestExecution['order']['state'] == "CANCELLED"
						tradeX.destroy
						next
					end
			  	requestOriginalE = Oanda.oandaTrade(apiKey, secretKey, requestExecution['order']['fillingTransactionID'])
			  	originalPrice = requestOriginalE['trade']['price'].to_f
					originalVolume = requestOriginalE['trade']['initialUnits'].to_f
				end

	  		profitTrigger = originalPrice * (0.01 * traderFound&.profitTrigger)
	  		volumeTallyForTradex = 0
	  		openProfitCount = 0

	  		case true
				when tvData['broker'] == 'KRAKEN'	
					profitTriggerPassed = (originalPrice + profitTrigger).round(1).to_f
				when tvData['broker'] == 'OANDA'	
					profitTriggerPassed = (originalPrice + profitTrigger).round(5).to_f
				end

			  case true
				when tvData['direction'] == 'sell'
					puts "Profit Trigger Price: #{(profitTriggerPassed + ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)).round(5)}"

					if tvData['currentPrice'].to_f > profitTriggerPassed
			  		if tradeX.take_profits.empty?
						  if tvData['currentPrice'].to_f > profitTriggerPassed + ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)
							  
					    	case true
								when tvData['broker'] == 'KRAKEN'
					  			@protectTrade = Kraken.newTrail(tvData,requestOriginalE, apiKey, secretKey, tradeX)
					  			if !@protectTrade.empty? && @protectTrade['result']['txid'].present?
					  				puts 	"\n-- Taking Profit #{@protectTrade['result']['txid'][0]} --\n"
					  			end
								when tvData['broker'] == 'OANDA'
									@protectTrade = Oanda.oandaTrail(tvData,requestExecution, apiKey, secretKey, tradeX)
					  			if !@protectTrade.empty? && @protectTrade['orderCreateTransaction']['id'].present?
					  				puts 	"\n-- Taking Profit #{@protectTrade['orderCreateTransaction']['id']} --\n"
					  			end
								end
			  			end
				  	else
				  		tradeX.take_profits.each do |profitTrade|
		  			  	case true
								when tvData['broker'] == 'KRAKEN'	
						  		requestProfitTradex = Kraken.orderInfo(profitTrade.uuid, apiKey, secretKey)
						  		profitTrade.update(status: requestProfitTradex['status'])
						  		volumeForProfit = requestProfitTradex['vol'].to_f
						  		priceToBeat = requestProfitTradex['descr']['price2'].to_f
								end

					  		if profitTrade.status == 'open' #or other status from oanda/alpaca
					  			volumeTallyForTradex += volumeForProfit
				  				openProfitCount += 1
					  			
						  		if (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) >  priceToBeat + ((0.01 * tvData['trail'].to_f) * (priceToBeat).round(1).to_f)
						  			case true
										when tvData['broker'] == 'KRAKEN'
							  			krakenOrderParams = {
										    "txid" 			=> profitTrade.uuid,
										  }
									  	routeToKraken = "/0/private/CancelOrder"
									  	
									  	cancel = Kraken.request(routeToKraken, krakenOrderParams, apiKey, secretKey)
									  	profitTrade.destroy
							  			puts "\n-- Old Take Profit Canceled --\n"
							  			
							  			@protectTrade = Kraken.newTrail(tvData,requestOriginalE, apiKey, secretKey, tradeX)
							  			if !@protectTrade.empty? && @protectTrade['result']['txid'].present?
							  				puts "\n-- Repainting Take Profit #{@protectTrade['result']['txid'][0]} --\n"
							  			end
										end
						  		end
					  		elsif profitTrade.status == 'closed' #or other status from oanda/alpaca
						  		volumeTallyForTradex += volumeForProfit
					  		elsif profitTrade.status == 'canceled' #or other status from oanda/alpaca
				  				puts "\n-- Removing Canceled Order #{profitTrade.uuid} --\n"
					  			profitTrade.destroy
					  			next
					  		end
				  		end
				  		
			  			
				  		if volumeTallyForTradex < originalVolume
				  			if openProfitCount == 0
				  				case true
									when tvData['broker'] == 'KRAKEN'
						  			@protectTrade = Kraken.newTrail(tvData,requestOriginalE, apiKey, secretKey, tradeX)
						  			if !@protectTrade.empty? && @protectTrade['result']['txid'].present?
						  				puts "\n-- Additional Take Profit #{@protectTrade['result']['txid'][0]} --\n"
						  			end
									end
					  		else
					  				puts "\n-- Waiting To Close Open Take Profit --\n"
				  			end
				  		else
				  			case true
								when tvData['broker'] == 'KRAKEN'
					  			checkFill = Kraken.orderInfo(tradeX.take_profits.last.uuid, apiKey, secretKey)
						  		tradeX.take_profits.last.update(status: checkFill['status'])
						  		if checkFill['status'] == 'closed'
							  		tradeX.update(finalTakeProfit: tradeX.take_profits.last.uuid)
							  		puts "\n-- Position Closed #{tradeX.uuid} --\n"
					  				puts "\n-- Last Profit Taken #{tradeX.take_profits.last.uuid} --\n"
						  		elsif checkFill['status'] == 'open'
						  			tradeX.update(finalTakeProfit:nil)
					  				puts "\n-- Waiting To Close Last Position --\n"
						  		end
								end
				  		end

				  	end
			  	end
				when tvData['direction'] == 'buy'
					
				end
	  	end
  	end

  	puts "Done Checking Profit"
	end

	def self.newEntry(tvData, apiKey = nil, secretKey = nil)
		case true
		when tvData['broker'] == 'KRAKEN'
			traderFound = User.find_by(krakenLiveAPI: apiKey)
		when tvData['broker'] == 'OANDA'
			traderFound = User.find_by(oandaToken: apiKey)
		end
		# if allowMarketOrder -> market order
		# if entries.count > 0 -> limit order

		# variables
  	case true
		when tvData['broker'] == 'KRAKEN'
			@unitsToTrade = Kraken.krakenRisk(tvData, apiKey, secretKey)
	  	
	  	if @unitsToTrade > 0 
				@pairCall = Kraken.publicPair(tvData, apiKey, secretKey)
		  	
				@resultKey = @pairCall['result'].keys.first
				@baseTicker = @pairCall['result'][@resultKey]['base']
				@tickerForAllocation = @pairCall['result'][@resultKey]['altname']
				
				@amountToRisk = Kraken.krakenBalance(apiKey, secretKey)
				@currentOpenAllocation = Kraken.pendingTrades(apiKey, secretKey)

				
				@tradeBalanceCall = Kraken.tradeBalance(@baseTicker, apiKey, secretKey)
				
				@accountTotal = @tradeBalanceCall['result']['eb'].to_f

				@currentRisk = ((@currentOpenAllocation.map{|d| d[1]}.reject{|d| d['descr']['type'] != tvData['direction']}.reject{|d| d['descr']['pair'] != @tickerForAllocation}.map{|d| d['vol'].to_f * d['descr']['price'].to_f}.sum + (@amountToRisk['result'][@baseTicker].to_f * tvData['currentPrice'].to_f))/(@accountTotal * tvData['currentPrice'].to_f)) * 100
	  	end
	  when tvData['broker'] == 'OANDA'
	  	@amountToRisk = Oanda.oandaRisk(tvData, apiKey, secretKey)
	  	oandaAccount = Oanda.oandaAccount(apiKey, secretKey)
	  	cleanTickers = oandaAccount['account']['positions'].map{|d| d['instrument'].tr!('_','')}

  		foundTickerPosition = oandaAccount['account']['positions'].reject{|d| d['instrument'] != tvData['ticker']}.first
  		foundTickerOrders = oandaAccount['account']['orders'].reject{|d| d['instrument'] != "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}"}

  		marginUsed = foundTickerPosition.present? && foundTickerPosition['marginUsed'].present? ? foundTickerPosition['marginUsed'].to_f : 0

  		@openOrders = (oandaAccount['account']['marginRate'].to_f * (foundTickerOrders.map{|d|d['units'].to_i}.sum))

			@currentRisk = (marginUsed + @openOrders) / ((marginUsed + @openOrders) + oandaAccount['account']['marginAvailable'].to_f) * 100
		end


		# ticker specific
		case true
    when tvData['ticker'] == 'BTCUSD'
    	@unitsFiltered = (@unitsToTrade > 0.0001 ? @unitsToTrade : 0.0001)
    end

		if (@currentRisk.round(2) <= traderFound&.maxRisk)


			# market order
			if traderFound&.allowMarketOrder == 'true'
				# set order params
		    case true
	  		when tvData['broker'] == 'KRAKEN'
					krakenOrderParams = {
				    "pair" 			=> tvData['ticker'],
				    "type" 			=> tvData['direction'],
				    "ordertype" => "market",
				    "volume" 		=> "#{@unitsFiltered}",
				  }
	  		when tvData['broker'] == 'OANDA'
	  			oandaOrderParams = {
					  'order' => {
					    'units' => "#{@amountToRisk == oandaAccount['account']['marginRate'].to_f ? 1 : @amountToRisk.round }",
					    'instrument' => "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}",
					    'timeInForce' => 'FOK',
					    'type' => 'MARKET',
					    'positionFill' => 'DEFAULT'
					  }
					}
	  		end


	  		# call order
	  		if tvData['direction'] == 'buy'
		  		case true
		  		when tvData['broker'] == 'KRAKEN'
					  requestK = Kraken.request('/0/private/AddOrder', krakenOrderParams, apiKey, secretKey)
		  		when tvData['broker'] == 'OANDA'
		  			requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
		  		end
		  	end


		  	# put order
			  if tvData['direction'] == 'sell'
			  	case true
			  	when tvData['broker'] == 'KRAKEN'
					  requestK = Kraken.request('/0/private/AddOrder', krakenOrderParams, apiKey, secretKey)
			  	when tvData['broker'] == 'OANDA'
		  			requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
			  	end
			  end


			  # update database with ID from requestK
			  case true
		  	when tvData['broker'] == 'KRAKEN'
				  if requestK.present? && requestK['result'].present?

						if requestK['result']['txid'].present?
							User.find_by(krakenLiveAPI: apiKey).trades.create(uuid:  requestK['result']['txid'][0], broker: tvData['broker'], direction: tvData['direction'], status: 'open')
					  	puts "\n-- #{tvData['broker']} Entry Submitted --\n"
					  end
					else 
					  if requestK['error'][0].present? && requestK['error'][0].include?("Insufficient")
					  	puts "\n-- MORE CASH FOR ENTRIES --\n"
					  end
					end
				when tvData['broker'] == 'OANDA'
					
					if requestK['orderCancelTransaction']['reason'].present?
						puts "\n-- #{requestK['orderCancelTransaction']['reason']} --\n"
					else
						User.find_by(oandaToken: apiKey).trades.create(uuid:  requestK['orderCreateTransaction']['id'], broker: tvData['broker'], direction: tvData['direction'], status: 'closed')
				  	puts "\n-- #{tvData['broker']} Entry Submitted --\n"
					end
		  	end
			end


			# limit order
			if tvData['entries'].reject(&:blank?).size > 0
				tvData['entries'].reject(&:blank?).each do |entryPercentage|
			    case true
		  		when tvData['broker'] == 'KRAKEN'
						priceToSet = (tvData['direction'] == 'sell' ? tvData['highPrice'].to_f + (tvData['highPrice'].to_f * (0.01 * entryPercentage.to_f)) : tvData['lowPrice'].to_f - (tvData['lowPrice'].to_f * (0.01 * entryPercentage.to_f))).round(1)
		  		when tvData['broker'] == 'OANDA'
						priceToSet = (tvData['direction'] == 'sell' ? tvData['highPrice'].to_f + (tvData['highPrice'].to_f * (0.01 * entryPercentage.to_f)) : tvData['lowPrice'].to_f - (tvData['lowPrice'].to_f * (0.01 * entryPercentage.to_f))).round(5)
					end
					# set order params

			    case true
		  		when tvData['broker'] == 'KRAKEN'
		  			krakenParams0 = {
					    "pair" 			=> tvData['ticker'],
					    "type" 			=> tvData['direction'],
					    "ordertype" => "limit",
					    "price" 		=> "#{priceToSet}",
					    "volume" 		=> "#{@unitsFiltered}",
					  }
					when tvData['broker'] == 'OANDA'
	  			oandaOrderParams = {
					  'order' => {
					  	'price' => "#{priceToSet}",
					    'units' => "#{@amountToRisk == oandaAccount['account']['marginRate'].to_f ? 1 : @amountToRisk.round }",
					    'instrument' => "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}",
					    'timeInForce' => 'GTC',
					    'type' => 'LIMIT',
					    'positionFill' => 'DEFAULT'
					  }
					}

					end
					# call order
			  	if tvData['direction'] == 'buy' 
					  case true
					  when tvData['broker'] == 'KRAKEN'
						  requestK = Kraken.request('/0/private/AddOrder', krakenParams0, apiKey, secretKey)
					  when tvData['broker'] == 'OANDA'
			  			requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
					  end
			  	end
			  	# put order
				  if tvData['direction'] == 'sell'
					  case true
					  when tvData['broker'] == 'KRAKEN'
						  requestK = Kraken.request('/0/private/AddOrder', krakenParams0, apiKey, secretKey)
					  when tvData['broker'] == 'OANDA'
			  			requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
					  end
				  end

				  # update database with ID from requestK
				  case true
				  when tvData['broker'] == 'KRAKEN'
					  if requestK.present? && requestK['result'].present?
						  if requestK['result']['txid'].present?
						  	User.find_by(krakenLiveAPI: apiKey).trades.create(uuid:  requestK['result']['txid'][0], broker: tvData['broker'], direction: tvData['direction'], status: 'open')
						  	puts "\n-- Kraken Entry Submitted --\n"
						  end
					  else
						  if requestK['error'][0].present? && requestK['error'][0].include?("Insufficient")
						  	puts "\n-- MORE CASH FOR ENTRIES --\n"
							end
					  end
				  when tvData['broker'] == 'OANDA'
						if requestK.present?
							User.find_by(oandaToken: apiKey).trades.create(uuid:  requestK['orderCreateTransaction']['id'], broker: tvData['broker'], direction: tvData['direction'], status: 'open')
					  	puts "\n-- #{tvData['broker']} Entry Submitted --\n"
						else
							puts "\n-- NOTHING --\n"
						end

				  end
				end
			else
  			puts "\n-- No Limit Orders Set --\n"
			end
		else
			puts "\n-- Max Risk Met (#{tvData['timeframe']} Minute) --\n"
			puts "\n-- Trader #{traderFound.uuid} --\n"
			puts "\n-- Current Risk (#{@currentRisk.round(2)}%) --\n"
			puts "\n-- Trader #{traderFound.uuid} --\n"
		end
	end

	# combine limit and market into one 'entry' call with logic to determine wich
end
