class Kraken < ApplicationRecord

	def self.krakenBalance
    routeToKraken = "/0/private/Balance"
    krakenRequest(routeToKraken)
  end

  def self.krakenPendingTrades
  	
    routeToKraken = "/0/private/OpenOrders"
    orderParams = {}
    requestK = krakenRequest(routeToKraken)['result']['open']
    createPayload = JsonDatum.create(params: orderParams, payload: requestK)
    createPayload[:payload]
  end
  
  def self.krakenTrades(filledOrNot = nil, page = nil)
  	buildTrades = []
    routeToKraken = "/0/private/TradesHistory"

    if page.present? && page.to_i > 1
    	orderParams = {
		    "trades" 			=> true,
		    "ofs" 			=> (page - 1) * 50,
		  }
	    requestK = krakenRequest(routeToKraken, orderParams)
    else
	    orderParams = {
		    "trades" 			=> true,
		  }	
	    requestK = krakenRequest(routeToKraken, orderParams)
		end

    # kResult = requestK['result']
    # kResultCount = kResult['count']

    # pagesToParse = (kResultCount/50.to_f).to_s.split('.')

    # pagesToParse[0].times do
	   #  if filledOrNot == 'filled'
	   #  	# grab closed orders with market or limit
	   #  else
	   #  	# grab orders not filled
	   #  end

    # end

    # grab remainder (pages % 1) or something like that
    # ".#{pagesToParse[1]}".round

    # return as JsonDatum with all results in array to iterate
    createPayload = JsonDatum.create(params: orderParams, payload: requestK['result']['trades'])
  	createPayload[:payload]
  end

  def self.krakenTrade(tradeID)
  	
    routeToKraken = "/0/private/QueryTrades"
    orderParams = {
	    "txid" 			=> tradeID,
	    "trades" 			=> true,
	  }	
    krakenRequest(routeToKraken, orderParams)
  end

  def self.krakenOrder(orderID)
  	
    routeToKraken = "/0/private/QueryOrders"
    orderParams = {
	    "txid" 			=> orderID,
	    "trades" 			=> true,
	  }	
    krakenRequest(routeToKraken, orderParams)
  end

  def self.removeCallOrders(tvData)
  	# a third
  	
  	tradesToUpdate = krakenPendingTrades
  	keysForTrades = tradesToUpdate.keys

  	#delete stop losses
  	keysForTrades.each do |keyX|
  		infoX = tradesToUpdate[keyX]
	  	if infoX['descr']['type'] != tvData['direction'] #and the same direction
		  	orderParams = {
			    "txid" 			=> keyX,
			  }
		  	routeToKraken = "/0/private/CancelOrder"
		  	krakenRequest(routeToKraken, orderParams)
	  	end
  	end
	end
 
	def self.removePutOrders(tvData)
  	# a third
  	
  	tradesToUpdate = krakenPendingTrades
  	keysForTrades = tradesToUpdate.keys

  	#delete stop losses
  	keysForTrades.each do |keyX|
  		infoX = tradesToUpdate[keyX]
	  	if infoX['descr']['type'] != tvData['direction'] #and the same direction
		  	orderParams = {
			    "txid" 			=> keyX,
			  }
		  	routeToKraken = "/0/private/CancelOrder"
		  	krakenRequest(routeToKraken, orderParams)
	  	end
  	end
	end

  def self.krakenTrailOrStop(tvData,tradeInfo)
  	# edit order
  	#update ClosedTrade Model with protection or info if needed
    routeToKraken = "/0/private/AddOrder"

    volumeToTake = tvData['tickerType'] == 'crypto' ? ((10 * 0.01) * tradeInfo['vol'].to_f).to_f : tvData['tickerType'] == 'forex' ? ((10 * 0.01) * tradeInfo['vol'].to_f).to_f.round : nil
    volumeString = ("%.5f" % volumeToTake)
    orderParams = {
	    "pair" 			=> tvData['ticker'],
	    "ordertype" => "stop-loss",
	    "type" 			=> tvData['direction'],
	    "price" 		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
	    "price2"		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.005 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.005 * tvData['trail'].to_f))).round(1)).to_s,
	    "volume" 		=> volumeString.to_f > 0.0001 ? ("%.5f" % volumeToTake) : "0.0001"
	  }

	  # remove all trailing first
    krakenRequest(routeToKraken, orderParams)
  end

  def self.krakenTrailStop(tvData)
  	# if in profit by less than tvData['trail'] -> set to break even
  	# if in profit by more than tvData['trail'] -> set to trail
  	# if not in profit -> hold

  	# find trades that are filled and opened 
		# krakenTrades('filled')
  	# paginate to get all results to create JsonDatum to pass to later methods
  	# delete in worker after [timeframe] delay

  	currentPositions = ClosedTrade.all.map(&:entry)
  	if currentPositions.size > 0
	  	currentPositions.each do |tradeID|

	  		requestK = krakenOrder(tradeID)
		  	sleep 0.5
	  		
	  		if afterSleep = requestK['result'][tradeID]

	  			if afterSleep['status'] != 'canceled' && (afterSleep['descr']['ordertype'] == 'limit' || afterSleep['descr']['ordertype'] == 'market')
					  makeorPull = ClosedTrade.find_by(entry: tradeID)
					  makeorPull.update(entryStatus: afterSleep['status'])
						#update protection

						if makeorPull&.protection.present?
							# krakenTrade(properTradeID)
							sleep 0.5
							pullProtexStatus = krakenOrder(makeorPull&.protection)
							protectedOrNah = pullProtexStatus['result'][makeorPull&.protection]['status']
							makeorPull&.update(protectionStatus: protectedOrNah)
						end
					end

					case true
					when tvData['direction'] == 'sell'
						@nextTakeProfit = (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['profitBy'].to_f))).round(1).to_f
					when tvData['direction'] == 'buy'
						@nextTakeProfit = (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['profitBy'].to_f))).round(1).to_f
					end

					if makeorPull&.entryStatus == 'closed'
						if makeorPull&.protection.nil?
							#set first time
			  			if tvData['direction'] == 'sell'
			  				if (@nextTakeProfit > afterSleep['price'].to_f)
			  					sleep 0.5
			  					protectTrade = krakenTrailOrStop(tvData,afterSleep)
								  puts "\n-- Setting Take Profit --\n"
								else
								  puts "\n-- Waiting For More Profit --\n"
				  			end
			  			end

			  			if tvData['direction'] == 'buy'
				  			if (@nextTakeProfit < afterSleep['price'].to_f)
				  				sleep 0.5
				  				protectTrade = krakenTrailOrStop(tvData,afterSleep)
								  puts "\n-- Setting Take Profit --\n"
								else
								  puts "\n-- Waiting For More Profit --\n"
				  			end
			  			end
		  				
		  				if protectTrade.present?
			  				sleep 0.5
			  				getStatus = krakenOrder(protectTrade['result']['txid'][0])
			  				makeorPull.update(protection: protectTrade['result']['txid'][0],protectionStatus: getStatus['result'][protectTrade['result']['txid'][0]]['status'])
					 		else
					 			puts "\n-- Waiting For More Profit --\n"
					 		end
					  elsif makeorPull&.protectionStatus != 'closed'
			  			#delete old order and repaint
			  			if tvData['direction'] == 'sell'
			  				if (@nextTakeProfit > afterSleep['price'].to_f)
			  					orderParams = {
								    "txid" 			=>  makeorPull&.protection,
								  }
								  puts "\n-- Repainting New Profit --\n"
								else
								  puts "\n-- Waiting For More Profit --\n"
				  				
				  			end
			  			end

			  			if tvData['direction'] == 'buy'
				  			if (@nextTakeProfit < afterSleep['price'].to_f)
				  				orderParams = {
								    "txid" 			=>  makeorPull&.protection,
								  }
								  puts "\n-- Repainting New Profit --\n"
								else
								  puts "\n-- Waiting For More Profit --\n"
				  				
				  			end
			  			end
			  			#delete old order if not already canceled

			  			if makeorPull&.protectionStatus.present? && makeorPull&.protectionStatus != 'canceled' && orderParams.present?
				  			sleep 0.5
				  			routeToKraken = "/0/private/CancelOrder"
						  	kcancel = krakenRequest(routeToKraken, orderParams)
						  	sleep 0.5
						  	protectTrade = krakenTrailOrStop(tvData,afterSleep)
						  	sleep 0.5
			  				getStatus = krakenOrder(protectTrade['result']['txid'][0])
			  				makeorPull.update(protection: protectTrade['result']['txid'][0],protectionStatus: getStatus['result'][protectTrade['result']['txid'][0]]['status'])
					  	elsif orderParams.present?
						  	#repaint new order
						  	sleep 0.5
						  	protectTrade = krakenTrailOrStop(tvData,afterSleep)
						  	sleep 0.5
			  				getStatus = krakenOrder(protectTrade['result']['txid'][0])
			  				makeorPull.update(protection: protectTrade['result']['txid'][0],protectionStatus: getStatus['result'][protectTrade['result']['txid'][0]]['status'])
					  	end
				  	elsif makeorPull&.protectionStatus == 'closed'
				  		# calculate profit and display
				  		requestK = krakenOrder(makeorPull&.entry)
				  		sleep 0.5
				  		entryX = requestK['result'][makeorPull&.entry]['price']

				  		requestKx = krakenOrder(makeorPull&.protection)
				  		sleep 0.5
				  		exitX = requestKx['result'][makeorPull&.protection]['price']
				  		
				  		case true
				  		when tvData['direction'] == 'sell'
								@profitMade = (exitX.to_f - entryX.to_f)
							when tvData['direction'] == 'buy'
								@profitMade = (entryX.to_f - exitX.to_f)
							end

				  		puts "Profit: #{@profitMade}"
				  	end
			  	end
		  	end
		  end
		else
			puts "No Current Positions"
		end
  end

  def self.krakenLimitOrder(tvData)
  	
  	# only create order if within 'trail' of last set order of this 'type' -> limit/market and account less than definedRisk from TV
  	unitsToTrade = xpercentForTradeFromTimeframe(tvData)

  	if unitsToTrade > 0 
  		# unitsWithScale
  		case true
  		when tvData['tickerType'] == 'crypto'
  			# execute kraken
  			# remove oposit orders first
  			# if tvData['direction'] == 'buy'
  			# 	removePutOrders(tvData)
  			# else
  			# 	removeCallOrders(tvData)
  			# end

			  tradesToUpdate = krakenPendingTrades
		  	keysForTrades = tradesToUpdate.keys



		  	pullPrices = []

		  	keysForTrades.each do |keyX|
		  		infoX = tradesToUpdate[keyX]
			  	if infoX['descr']['type'] == tvData['direction'] #and the same direction
				  	pullPrices << [{price: infoX['descr']['price'].to_f, tradeID: keyX}]
			  	end

			  	if infoX['descr']['ordertype'] == 'market' || infoX['descr']['ordertype'] == 'limit' #and the same direction
				  	ClosedTrade.find_or_create_by(entry: keyX)
			  	end
		  	end

  			tvData['trail'].each do |trailPercent|

	  			priceToSet = (tvData['direction'] == 'sell' ? tvData['highPrice'].to_f + (tvData['highPrice'].to_f * (0.01 * trailPercent.to_f)) : tvData['lowPrice'].to_f - (tvData['lowPrice'].to_f * (0.01 * trailPercent.to_f))).round(1)
	  			# allow multiple ranges of set prices from tvData
			    # ( unitsToTrade > 0.0001) : tvData['ticker'] == 'PAXGUSD' ? : unitsToTrade
		    	unitsFiltered = unitsToTrade

			    case true
			    when tvData['ticker'] == 'BTCUSD'
			    	unitsFiltered = (unitsToTrade > 0.0001 ? unitsToTrade : 0.0001)
			    when tvData['ticker'] == 'PAXGUSD'
			    	unitsFiltered = (unitsToTrade > 0.003 ? unitsToTrade : 0.003)
			    end

	  			orderParams = {
				    "pair" 			=> tvData['ticker'],
				    "type" 			=> tvData['direction'],
				    "ordertype" => "limit",
				    "price" 		=> priceToSet,
				    "volume" 		=> "#{unitsFiltered}"
				  }

			  	pricePulled = pullPrices.flatten.map{|p| p[:price]}

			  	if tvData['direction'] == 'buy' && (priceToSet < (pricePulled&.min + (pricePulled&.min.to_f * (0.01 * trailPercent.to_f))))
					  #remove current pendingOrder in this position
					  requestK = krakenRequest('/0/private/AddOrder', orderParams)
			  	end
			  	
				  if tvData['direction'] == 'sell' && (priceToSet > (pricePulled&.max - (pricePulled&.max.to_f * (0.01 * trailPercent.to_f))))
					  #remove current pendingOrder in this position
					  requestK = krakenRequest('/0/private/AddOrder', orderParams)
				  end

				  if requestK.present?
					  if requestK['error'][0].present? && requestK['error'][0].include?("Insufficient")
					  	puts "\n-- MORE CASH FOR ENTRIES --\n"
						end
						
					  if requestK['result']['txid'].present?
						  firstMake = ClosedTrade.create(entry: requestK['result']['txid'][0], entryStatus: 'open')
						  getOrder = krakenOrder(requestK['result']['txid'][0])['result']
						  firstMake.update(entryStatus: getOrder[requestK['result']['txid'][0]]['status'])
					  	puts "\n-- Kraken Entry Submitted --\n"
					  end
				  else
				  	puts "\n-- Waiting For Better Entry --\n"
				  end
  			end

  		when tvData['tickerType'] == 'forex'
  			# execute oanda
  		end
  	end
  end

  def self.krakenMarketOrder(tvData)
  	# only create order if within 'trail' of last set order of this 'type' -> limit/market and account less than definedRisk from TV
  	unitsToTrade = xpercentForTradeFromTimeframe(tvData)

  	if unitsToTrade > 0 
  		# unitsWithScale
  		case true
  		when tvData['tickerType'] == 'crypto'
  			# execute kraken
  			# remove oposit orders first
  			if tvData['direction'] == 'buy'
  				removePutOrders(tvData)
  			else
  				removeCallOrders(tvData)
  			end

  			priceToSet = (tvData['currentPrice']).to_f.round(1)

  			case true
		    when tvData['ticker'] == 'BTCUSD'
		    	unitsFiltered = (unitsToTrade > 0.0001 ? unitsToTrade : 0.0001)
		    when tvData['ticker'] == 'PAXGUSD'
		    	unitsFiltered = (unitsToTrade > 0.003 ? unitsToTrade : 0.003)
		    end

  			orderParams = {
			    "pair" 			=> tvData['ticker'],
			    "type" 			=> tvData['direction'],
			    "ordertype" => "market",
			    "volume" 		=> "#{unitsFiltered}" 
			  }	

				# averageOfPricesOpen = (pullPrices&.sum/pullPrices&.count)
		  	if tvData['direction'] == 'buy'
				  @requestK = krakenRequest('/0/private/AddOrder', orderParams)
		  	end

			  if tvData['direction'] == 'sell'
				  @requestK = krakenRequest('/0/private/AddOrder', orderParams)
			  end
			  if @requestK.present?
				  if @requestK['error'][0].present? && @requestK['error'][0].include?("Insufficient")
				  	puts "\n-- MORE CASH FOR ENTRIES --\n"
				  end
			  end

			  if @requestK.present?
				  if @requestK['error'][0].present? && @requestK['error'][0].include?("Insufficient")
				  	puts "\n-- MORE CASH FOR ENTRIES --\n"
				  end

					if @requestK['result']['txid'].present?
					  firstMake = ClosedTrade.create(entry: @requestK['result']['txid'][0], entryStatus: 'open')
					  getOrder = krakenOrder(@requestK['result']['txid'][0])['result']
					  firstMake.update(entryStatus: getOrder[@requestK['result']['txid'][0]]['status'])
				  	puts "\n-- Kraken Entry Submitted --\n"
				  end
				end

  		when tvData['tickerType'] == 'forex'
  			# execute oanda
  		end
  	end
  end


  def self.xpercentForTradeFromTimeframe(tvData)
  	#make work for kraken and oanda

  	currentPrice = tvData['currentPrice'].to_f

  	if tvData['tickerType'] == 'crypto' && tvData['broker'] == 'kraken'
  		requestK = krakenBalance
  		accountBalance = requestK['ZUSD'].to_f
  	end

  	if tvData['ticker'] == 'EURUSD'
  		# accountBalance = accountBalanceForOanda
  	end
  	
    case true
  	when tvData['timeframe'] == '15'
  		tvData['tickerType'] == 'crypto' ? (((0.25* 0.01) * accountBalance / currentPrice).to_f > 3 ? ((0.25* 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f) : tvData['tickerType'] == 'forex' ? ((0.25* 0.01) * accountBalance / currentPrice).to_f.round : nil
  	when tvData['timeframe'] == '30'
  		tvData['tickerType'] == 'crypto' ? (((0.50* 0.01) * accountBalance / currentPrice).to_f > 3 ? ((0.50* 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f) : tvData['tickerType'] == 'forex' ? ((0.50* 0.01) * accountBalance / currentPrice).to_f.round : nil
  	when tvData['timeframe'] == '60'
  		tvData['tickerType'] == 'crypto' ? (((0.75* 0.01) * accountBalance / currentPrice).to_f > 3 ? ((0.75* 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f) : tvData['tickerType'] == 'forex' ? ((0.75* 0.01) * accountBalance / currentPrice).to_f.round : nil
  	when tvData['timeframe'] == '120'
  		tvData['tickerType'] == 'crypto' ? (((1* 0.01) * accountBalance / currentPrice).to_f > 3 ? ((1* 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f) : tvData['tickerType'] == 'forex' ? ((1* 0.01) * accountBalance / currentPrice).to_f.round : nil
  	end
  end
  
  # def self.createTakeProfitOrder(tvData)
  # 	xpercentForTradeFromTimeframe
  #   routeToKraken = "/0/private/Balance"
  #   krakenRequest(routeToKraken)
  # end

end


