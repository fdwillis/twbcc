class ApplicationRecord < ActiveRecord::Base
	self.abstract_class = true

	def self.trailStop(tvData, apiKey = nil, secretKey = nil)
		puts "\n-- Current Price: #{tvData['currentPrice'].to_f.round(1)} --\n"
		case true
		when tvData['broker'] == 'kraken'
			openTrades = User.find_by(krakenLiveAPI: apiKey).trades.where(status: 'open', broker: tvData['broker'])
			
		end
		if openTrades.present? && openTrades.size > 0 
	  	openTrades.each do |trade| # go update known limit orders status
	  		Thread.pass
	  		case true
				when tvData['broker'] == 'kraken'
		  		requestK = Kraken.krakenOrder(trade.uuid, apiKey, secretKey)
		  		trade.update(status: requestK['status'])
					
				end
	  		if trade.status == 'canceled'
	  			trade.destroy
		  	end
	  	end
  	end
  	
  	# pull current pending orders for sync of database
  	case true
		when tvData['broker'] == 'kraken'
	  	afterUpdates = User.find_by(krakenLiveAPI: apiKey).trades.where(status: 'closed', broker: tvData['broker'], finalTakeProfit: nil)
		end
  	
  	if afterUpdates.present? && afterUpdates.size > 0	
	  	afterUpdates.each do |tradeX|
			  Thread.pass
	    	case true
				when tvData['broker'] == 'kraken'	
		  		requestOriginalE = Kraken.krakenOrder(tradeX.uuid, apiKey, secretKey)
				end

	  		originalPrice = requestOriginalE['price'].to_f
	  		profitTrigger = originalPrice * (0.01 * tvData['profitTrigger'].to_f)
	  		volumeTallyForTradex = 0
	  		openProfitCount = 0

			  case true
				when tvData['direction'] == 'sell'
					profitTriggerPassed = (originalPrice + profitTrigger).round(1).to_f
					puts "Profit Trigger Price: #{(profitTriggerPassed + ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)).round(1)}"

					if tvData['currentPrice'].to_f > profitTriggerPassed
			  		if tradeX.take_profits.empty?
						  if tvData['currentPrice'].to_f > profitTriggerPassed + ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)
							  Thread.pass
					    	case true
								when tvData['broker'] == 'kraken'
					  			@protectTrade = Kraken.krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey, tradeX)
					  			if @protectTrade.present? && @protectTrade['result']['txid'].present?
					  				puts 	"\n-- Taking Profit #{@protectTrade['result']['txid'][0]} --\n"
					  			end
									
								end
			  			end
				  	else
				  		tradeX.take_profits.each do |profitTrade|
				  			Thread.pass
		  			  	case true
								when tvData['broker'] == 'kraken'	
						  		requestProfitTradex = Kraken.krakenOrder(profitTrade.uuid, apiKey, secretKey)
						  		profitTrade.update(status: requestProfitTradex['status'])
								end

								if profitTrade.status == 'canceled'
					  			profitTrade.destroy
						  	end

					  		if profitTrade.status == 'open'
					  			volumeTallyForTradex += requestProfitTradex['vol'].to_f
				  				openProfitCount += 1
					  			
						  		if (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) >  requestProfitTradex['descr']['price2'].to_f + ((0.01 * tvData['trail'].to_f) * (requestProfitTradex['descr']['price2'].to_f).round(1).to_f)
						  			
						  			orderParams = {
									    "txid" 			=> profitTrade.uuid,
									  }
								  	routeToKraken = "/0/private/CancelOrder"
								  	Thread.pass
								  	cancel = Kraken.krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
								  	profitTrade.destroy
						  			puts "\n-- Old Take Profit Canceled --\n"
						  			Thread.pass
						  			@protectTrade = Kraken.krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey, tradeX)
						  			if @protectTrade.present? && @protectTrade['result']['txid'].present?
						  				puts "\n-- Repainting Take Profit #{@protectTrade['result']['txid'][0]} --\n"
						  			end
						  		end
					  		elsif profitTrade.status == 'closed'
						  		volumeTallyForTradex += requestProfitTradex['vol'].to_f
					  		elsif profitTrade.status == 'canceled'
				  				puts "\n-- Removing Canceled Order #{profitTrade.uuid} --\n"
					  			profitTrade.destroy
					  			next
					  		end
					  		
				  		end
				  		
			  			Thread.pass
				  		if volumeTallyForTradex < requestOriginalE['vol'].to_f
				  			if openProfitCount == 0
					  			@protectTrade = Kraken.krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey, tradeX)
					  			if @protectTrade.present? && @protectTrade['result']['txid'].present?
					  				puts "\n-- Additional Take Profit #{@protectTrade['result']['txid'][0]} --\n"
					  			end
					  		else
					  				puts "\n-- Waiting To Close Open Take Profit --\n"
				  			end
				  		else
				  			checkFill = Kraken.krakenOrder(tradeX.take_profits.last.uuid, apiKey, secretKey)
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
				when tvData['direction'] == 'buy'
					profitTriggerPassed = (originalPrice - profitTrigger).round(1).to_f
					if tvData['currentPrice'].to_f < profitTriggerPassed - ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)
						
					end
				end
	  	end
  	end

  	puts "Done With Profit"
	end

	def self.limitOrder(tvData, apiKey = nil, secretKey = nil)
		case true
		when tvData['broker'] == 'kraken'
			
			@unitsToTrade = Kraken.xpercentForTradeFromTimeframe(tvData, apiKey, secretKey)
	  	
	  	if @unitsToTrade > 0 
	  		# unitsWithScale
		  	Thread.pass
				@pairCall = Kraken.publicPair(tvData, apiKey, secretKey)
		  	Thread.pass
				@resultKey = @pairCall['result'].keys.first
				@baseTicker = @pairCall['result'][@resultKey]['base']
				@tickerForAllocation = @pairCall['result'][@resultKey]['altname']
				Thread.pass
				@currentAllocation = Kraken.krakenBalance(apiKey, secretKey)
				@currentOpenAllocation = Kraken.krakenPendingTrades(apiKey, secretKey)

				Thread.pass
				@tickerInfoCall = Kraken.tickerInfo(@baseTicker, apiKey, secretKey)
				Thread.pass
				@accountTotal = @tickerInfoCall['result']['eb'].to_f

				@currentRisk = ((@currentOpenAllocation.map{|d| d[1]}.reject{|d| d['descr']['type'] != tvData['direction']}.reject{|d| d['descr']['pair'] != @tickerForAllocation}.map{|d| d['vol'].to_f * d['descr']['price'].to_f}.sum + (@currentAllocation['result'][@baseTicker].to_f * tvData['currentPrice'].to_f))/(@accountTotal * tvData['currentPrice'].to_f)) * 100
	  	end
		end

		if (@currentRisk.round(2) <= tvData['maxRisk'].to_f)
	  	if tvData['entries'].reject(&:blank?).size > 0
  			tvData['entries'].reject(&:blank?).each do |entryPercentage|

	  			priceToSet = (tvData['direction'] == 'sell' ? tvData['highPrice'].to_f + (tvData['highPrice'].to_f * (0.01 * entryPercentage.to_f)) : tvData['lowPrice'].to_f - (tvData['lowPrice'].to_f * (0.01 * entryPercentage.to_f))).round(1)

				  case true
				  when tvData['broker'] == 'kraken'
				    case true
				    when tvData['ticker'] == 'BTCUSD'
				    	@unitsFiltered = (@unitsToTrade > 0.0001 ? @unitsToTrade : 0.0001)
				    end

		  			@orderParams = {
					    "pair" 			=> tvData['ticker'],
					    "type" 			=> tvData['direction'],
					    "ordertype" => "limit",
					    "price" 		=> priceToSet,
					    "volume" 		=> "#{@unitsFiltered}",
					  }

					  # if within maxRisk

					  Thread.pass
				  	if tvData['direction'] == 'buy' 
						  case true
						  when tvData['broker'] == 'kraken'
							  #remove current pendingOrder in this position
							  @requestK = Kraken.krakenRequest('/0/private/AddOrder', @orderParams, apiKey, secretKey)
						  	
						  end
				  	end
				  	
					  if tvData['direction'] == 'sell'
						  case true
						  when tvData['broker'] == 'kraken'
							  #remove current pendingOrder in this position
							  @requestK = Kraken.krakenRequest('/0/private/AddOrder', @orderParams, apiKey, secretKey)
						  	
						  end
					  end

					  case true
					  when tvData['broker'] == 'kraken'
						  if @requestK.present? && @requestK['result'].present?
							  if @requestK['result']['txid'].present?
							  	User.find_by(krakenLiveAPI: apiKey).trades.create(uuid:  @requestK['result']['txid'][0], broker: tvData['broker'], direction: tvData['direction'], status: 'open')
							  	puts "\n-- Kraken Entry Submitted --\n"
							  end
						  else
							  if @requestK['error'][0].present? && @requestK['error'][0].include?("Insufficient")
							  	puts "\n-- MORE CASH FOR ENTRIES --\n"
								else
							  	puts "\n-- Waiting For Better Entry --\n"
								end
						  end
					  end
				  end

  			end
  		else
  			puts "\n-- No Limit Orders Set --\n"
			end
		else
			puts "\n-- Max Risk Met (#{tvData['timeframe']} Minute) --\n"
			puts "\n-- Current Risk (#{@currentRisk.round(2)}%) --\n"
		end
	end

	def self.marketOrder(tvData, apiKey = nil, secretKey = nil) #entry
  	# only create order if within 'trail' of last set order of this 'type' -> limit/market and account less than definedRisk from TV

  	case true
		when tvData['broker'] == 'kraken'
			
			@unitsToTrade = Kraken.xpercentForTradeFromTimeframe(tvData, apiKey, secretKey)
	  	
	  	if @unitsToTrade > 0 
	  		# unitsWithScale
		  	Thread.pass
				@pairCall = Kraken.publicPair(tvData, apiKey, secretKey)
		  	Thread.pass
				@resultKey = @pairCall['result'].keys.first
				@baseTicker = @pairCall['result'][@resultKey]['base']
				@tickerForAllocation = @pairCall['result'][@resultKey]['altname']
				Thread.pass
				@currentAllocation = Kraken.krakenBalance(apiKey, secretKey)
				@currentOpenAllocation = Kraken.krakenPendingTrades(apiKey, secretKey)

				Thread.pass
				@tickerInfoCall = Kraken.tickerInfo(@baseTicker, apiKey, secretKey)
				Thread.pass
				@accountTotal = @tickerInfoCall['result']['eb'].to_f

				@currentRisk = ((@currentOpenAllocation.map{|d| d[1]}.reject{|d| d['descr']['type'] != tvData['direction']}.reject{|d| d['descr']['pair'] != @tickerForAllocation}.map{|d| d['vol'].to_f * d['descr']['price'].to_f}.sum + (@currentAllocation['result'][@baseTicker].to_f * tvData['currentPrice'].to_f))/(@accountTotal * tvData['currentPrice'].to_f)) * 100
	  	end
		end



		if (@currentRisk.round(2) <= tvData['maxRisk'].to_f)
			case true
	    when tvData['ticker'] == 'BTCUSD'
	    	@unitsFiltered = (@unitsToTrade > 0.0001 ? @unitsToTrade : 0.0001)
	    end

			orderParams = {
		    "pair" 			=> tvData['ticker'],
		    "type" 			=> tvData['direction'],
		    "ordertype" => "market",
		    "volume" 		=> "#{@unitsFiltered}",
		  }

		  Thread.pass
			# averageOfPricesOpen = (pullPrices&.sum/pullPrices&.count)
	  	if tvData['direction'] == 'buy'
	  		case true
	  		when tvData['broker'] == 'kraken'
				  requestK = Kraken.krakenRequest('/0/private/AddOrder', orderParams, apiKey, secretKey)
	  		end
	  	end

		  if tvData['direction'] == 'sell'
		  	case true
		  	when tvData['broker'] == 'kraken'
				  requestK = Kraken.krakenRequest('/0/private/AddOrder', orderParams, apiKey, secretKey)
		  	end
		  end

		  case true
	  	when tvData['broker'] == 'kraken'
			  if requestK.present? && requestK['result'].present?

					if requestK['result']['txid'].present?
						User.find_by(krakenLiveAPI: apiKey).trades.create(uuid:  requestK['result']['txid'][0], broker: tvData['broker'], direction: tvData['direction'], status: 'closed')
				  	puts "\n-- Kraken Entry Submitted --\n"
				  end
				else 
				  if requestK['error'][0].present? && requestK['error'][0].include?("Insufficient")
				  	puts "\n-- MORE CASH FOR ENTRIES --\n"
				  end
				end
	  	end

		else
			puts "\n-- Max Risk Met (#{tvData['timeframe']} Minute) --\n"
			puts "\n-- Current Risk (#{@currentRisk.round(2)}%) --\n"
		end
  end

end
