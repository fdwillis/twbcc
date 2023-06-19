class Kraken
	# self.abstract_class = true
	def self.get_kraken_signature(uri_path, api_nonce, api_sec, api_post, secretKey)
    api_sha256 = OpenSSL::Digest.new('sha256').digest("#{api_nonce}#{api_post}")
    api_hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha512'), Base64.decode64(secretKey), "#{uri_path}#{api_sha256}")
    Base64.strict_encode64(api_hmac)
  end

  # Attaches auth headers and returns results of a POST request
  def self.krakenRequest(uri_path, orderParams = {}, apiKey, secretKey)
    api_nonce = (Time.now.to_f * 1000).to_i.to_s
    post_data = orderParams.present? ? orderParams.map { |key, value| "#{key}=#{value}" }.join('&') : nil
    api_post = (orderParams.present? ? "nonce=#{api_nonce}&#{post_data}" : "nonce=#{api_nonce}")
    api_signature = get_kraken_signature(uri_path, api_nonce, apiKey, api_post, secretKey)
    
    headers = {
      "API-Key" => apiKey,
      "API-Sign" => api_signature
    }
    
    uri = URI("https://api.kraken.com" + uri_path)
    req = Net::HTTP::Post.new(uri.path, headers)
    orderParams.present? ? req.set_form_data({ "nonce" => api_nonce }.merge(orderParams)) : req.set_form_data({ "nonce" => api_nonce })
    req.body = CGI.unescape(req.body)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(req)
    sleep 1
    Oj.load(response.body)
  end

	def self.krakenBalance(apiKey, secretKey)
    routeToKraken = "/0/private/Balance"
    krakenRequest(routeToKraken, nil, apiKey, secretKey)
  end

  def self.krakenPendingTrades(apiKey, secretKey)
  	
    routeToKraken = "/0/private/OpenOrders"
    orderParams = {}
    requestK = krakenRequest(routeToKraken, orderParams, apiKey, secretKey)['result']['open']
  end

  def self.krakenClosedTrades(apiKey, secretKey)
  	
    routeToKraken = "/0/private/ClosedOrders"
    orderParams = {}
    requestK = krakenRequest(routeToKraken, orderParams, apiKey, secretKey)['result']['closed']
  end

  def self.tickerInfo(symbol, apiKey, secretKey)
  	
    routeToKraken = "/0/private/TradeBalance"
    orderParams = {
    	"asset" => symbol
    }

    requestK = krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
  end

  def self.publicPair(tvData, apiKey, secretKey)
    routeToKraken = "/0/public/AssetPairs"
    orderParams = {
    	"pair" => tvData['ticker']
    }

    requestK = krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
  end

  def self.krakenOrder(orderID, apiKey, secretKey)
  	
    routeToKraken = "/0/private/QueryOrders"
    orderParams = {
	    "txid" 			=> orderID,
	    "trades" 			=> true,
	  }	
    krakenRequest(routeToKraken, orderParams, apiKey, secretKey)['result'][orderID]
  end

  def self.krakenTrailOrStop(tvData,tradeInfo, apiKey, secretKey)
  	# edit order
  	#hard coded min for bitcoin
  	#update ClosedTrade Model with protection or info if needed

  	if tvData['reduceBy'].present? && tvData['reduceBy'].to_f != 100
  		#  take tvData['reduceBy'] now
	    routeToKraken = "/0/private/AddOrder"

	    orderParams = {
		    "pair" 			=> tradeInfo['descr']['pair'],
		    "ordertype" => "take-profit-limit",
		    "type" 			=> tradeInfo['descr']['type'],
		    "price" 		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
		    "price2"		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
		    "volume" 		=> (tradeInfo['vol'].to_f * (0.01 * tvData['reduceBy'].to_f)).to_s
		  }
		  Thread.pass
	    krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
	  end

	  if tvData['reduceBy'].present? && tvData['reduceBy'].to_f == 100
	  	# take all of it
	    routeToKraken1 = "/0/private/AddOrder"

	    orderParams1 = {
		    "pair" 			=> tradeInfo['descr']['pair'],
		    "ordertype" => "take-profit-limit",
		    "type" 			=> tradeInfo['descr']['type'],
		    "price" 		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
		    "price2"		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
		    "volume" 		=> tradeInfo['vol']
		  }
		  Thread.pass
		  # remove all trailing first
	    krakenRequest(routeToKraken1, orderParams1, apiKey, secretKey)
	  end
  end

  def self.krakenTrailStop(tvData, apiKey, secretKey)
  	# if in profit by less than tvData['trail'] -> set to break even
  	# if in profit by more than tvData['trail'] -> set to trail
  	# if not in profit -> hold
		puts "Current Price: #{tvData['currentPrice'].to_f.round(1)}"

		openTrades = User.find_by(krakenLiveAPI: apiKey).trades.where(status: 'open', broker: tvData['broker'])
  	openTrades.each do |trade| # go update known limit orders status
  		Thread.pass
  		requestK = krakenOrder(trade.uuid, apiKey, secretKey)

  		trade.update(status: requestK['status'])
  	end
  	
  	afterUpdates = User.find_by(krakenLiveAPI: apiKey).trades.where(status: 'closed', broker: tvData['broker'], finalTakeProfit: nil)
  	
  	afterUpdates.each do |tradeX|
		  Thread.pass
		  
  		requestOriginalE = krakenOrder(tradeX.uuid, apiKey, secretKey)

  		originalPrice = requestOriginalE['price'].to_f
  		profitTrigger = originalPrice * (0.01 * tvData['profitTrigger'].to_f)
  		volumeTallyForTradex = 0

		  case true
			when tvData['direction'] == 'sell'
				profitTriggerPassed = (originalPrice + profitTrigger).round(1).to_f
				puts "Profit Trigger Price: #{(profitTriggerPassed + ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)).round(1)}"

				if tvData['currentPrice'].to_f > profitTriggerPassed + ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)
		  		if tradeX.take_profits.empty?
					  Thread.pass
		  			@protectTrade = krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey)
		  			puts 	"\n-- Setting Take Profit #{@protectTrade['result']['txid'][0]} --\n"
		  			tradeX.take_profits.create(uuid: @protectTrade['result']['txid'][0], status: 'open',direction: tvData['direction'], broker: tvData['broker'])
			  	else
			  		tradeX.take_profits.each do |profitTrade|
			  			Thread.pass
				  		requestProfitTradex = krakenOrder(profitTrade.uuid, apiKey, secretKey)
				  		profitTrade.update(status: requestProfitTradex['status'])

				  		if requestProfitTradex['status'] == 'open'
					  		if (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) >  requestProfitTradex['descr']['price2'] + ((0.01 * tvData['trail'].to_f) * (requestProfitTradex['descr']['price2']).round(1).to_f)
					  			
					  			orderParams = {
								    "txid" 			=> profitTrade.uuid,
								  }
							  	routeToKraken = "/0/private/CancelOrder"
							  	Thread.pass
							  	cancel = krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
							  	TakeProfit.find_by(uuid: profitTrade.uuid).destroy
					  			puts "\n-- Old Take Profit Canceled --\n"
					  			Thread.pass
					  			@protectTrade = krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey)
					  			puts "\n-- Repainting Take Profit #{@protectTrade['result']['txid'][0]} --\n"
					  			tradeX.take_profits.create(uuid: @protectTrade['result']['txid'][0], status: 'open', direction: tvData['direction'], broker: tvData['broker'])
					  		end
				  		end

				  		if requestProfitTradex['status'] == 'closed'
				  			
					  		volumeTallyForTradex += requestProfitTradex['vol'].to_f
				  		end
			  		end

			  		if volumeTallyForTradex > 0 && volumeTallyForTradex < requestOriginalE['vol'].to_f
			  			
			  			Thread.pass
			  			@protectTrade = krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey)
			  			puts "\n-- Setting Additional Take Profit #{@protectTrade['result']['txid'][0]} --\n"
			  			tradeX.take_profits.create(uuid: @protectTrade['result']['txid'][0], status: 'open', direction: tvData['direction'], broker: tvData['broker'])
				  	else
				  		tradeX.update(finalTakeProfit: tradeX.take_profits.last.uuid)
			  		end
			  	end
		  	end
			when tvData['direction'] == 'buy'
				profitTriggerPassed = (originalPrice - profitTrigger).round(1).to_f
				if tvData['currentPrice'].to_f < profitTriggerPassed - ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)
					# if tradeX.take_profits.nil?
					#   Thread.pass
		  		# 	@protectTrade = krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey)
		  		# 	puts "\n-- Setting Take Profit #{@protectTrade['result']['txid']} --\n"
		  		# 	tradeX.take_profits.create(uuid: @protectTrade['result']['txid'], status: 'open', direction: tvData['direction'], broker: tvData['broker'])
			  	# else
			  	# 	volumeTallyForTradex = 0

			  	# 	tradeX.take_profits.each do |profitTrade|
			  	# 		Thread.pass
				  # 		requestProfitTradex = krakenOrder(profitTrade.uuid, apiKey, secretKey)
				  # 		profitTrade.update(status: requestProfitTradex['status'])
				  # 		if requestProfitTradex['status'] == 'open'
					#   		# curernt price plus trail is better than original take profit order set -> replace old take profit order
					#   		if (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) >  profitTriggerPassed + ((0.01 * tvData['trail'].to_f) * (originalPrice + profitTrigger).round(1).to_f)
					#   			Thread.pass
					#   			@protectTrade = krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey)
					#   			puts "\n-- Setting Take Profit #{@protectTrade['result']['txid']} --\n"
					#   			tradeX.take_profits.create(uuid: @protectTrade['result']['txid'], status: 'open', direction: tvData['direction'], broker: tvData['broker'])
					#   		end
				  # 		end

				  # 		if requestProfitTradex['status'] == 'closed'
					#   		volumeTallyForTradex += requestProfitTradex['vol'].to_f
				  # 		end

			  	# 	end

			  	# 	if volumeTallyForTradex < requestOriginalE['vol'].to_f
			  	# 		Thread.pass
			  	# 		@protectTrade = krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey)
			  	# 		puts "\n-- Setting Take Profit #{@protectTrade['result']['txid']} --\n"
			  	# 		tradeX.take_profits.create(uuid: @protectTrade['result']['txid'], status: 'open', direction: tvData['direction'], broker: tvData['broker'])
				  # 	else
				  # 		tradeX.update(finalTakeProfit: tradeX.take_profits)
			  	# 	end
			  	# end
				end
			end
  	end

  	puts "Done With Profit"
  end

  def self.krakenLimitOrder(tvData, apiKey, secretKey) #entry
  	
  	# only create order if within 'trail' of last set order of this 'type' -> limit/market and account less than definedRisk from TV
  	unitsToTrade = xpercentForTradeFromTimeframe(tvData, apiKey, secretKey)
  	if unitsToTrade > 0 
  		# unitsWithScale
	  	Thread.pass
  		case true
  		when tvData['tickerType'] == 'crypto'
				pairCall = publicPair(tvData, apiKey, secretKey)
		  	Thread.pass
				resultKey = pairCall['result'].keys.first
				baseTicker = pairCall['result'][resultKey]['base']
				Thread.pass
				currentAllocation = krakenBalance(apiKey, secretKey)
				Thread.pass
				tickerInfoCall = tickerInfo(baseTicker, apiKey, secretKey)
				Thread.pass
				accountTotal = tickerInfoCall['result']['eb'].to_f

				currentRisk = (currentAllocation['result'][baseTicker].to_f/accountTotal) * 100
				
				if (currentRisk <= tvData['maxRisk'].to_f)
			  	if tvData['entries'].reject(&:blank?).size > 0
		  			tvData['entries'].reject(&:blank?).each do |entryPercentage|

			  			priceToSet = (tvData['direction'] == 'sell' ? tvData['highPrice'].to_f + (tvData['highPrice'].to_f * (0.01 * entryPercentage.to_f)) : tvData['lowPrice'].to_f - (tvData['lowPrice'].to_f * (0.01 * entryPercentage.to_f))).round(1)
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
						    "volume" 		=> "#{unitsFiltered}",
						    "close[ordertype]" => "take-profit-limit",
						    "close[price]" 	=> (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['maxProfit'].to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['maxProfit'].to_f))))).round(1).to_s,
						    "close[price2]" => (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['maxProfit'].to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['maxProfit'].to_f))))).round(1).to_s,
						  }

						  # if within maxRisk

						  Thread.pass
					  	if tvData['direction'] == 'buy' 
							  #remove current pendingOrder in this position
						  requestK = krakenRequest('/0/private/AddOrder', orderParams, apiKey, secretKey)
					  	end
					  	
						  if tvData['direction'] == 'sell'
							  #remove current pendingOrder in this position
							  requestK = krakenRequest('/0/private/AddOrder', orderParams, apiKey, secretKey)
						  end

						  if requestK.present? && requestK['result'].present?
							  if requestK['result']['txid'].present?
							  	User.find_by(krakenLiveAPI: apiKey).trades.create(uuid:  requestK['result']['txid'][0], broker: tvData['broker'], direction: tvData['direction'], status: 'open')
							  	puts "\n-- Kraken Entry Submitted --\n"
							  end
						  else
							  if requestK['error'][0].present? && requestK['error'][0].include?("Insufficient")
							  	puts "\n-- MORE CASH FOR ENTRIES --\n"
								else
							  	puts "\n-- Waiting For Better Entry --\n"
								end
						  end
		  			end
		  		else
		  			puts "\n-- No Limit Orders Set --\n"
	  			end
	  		else
	  			puts "\n-- Max Risk Met (#{tvData['timeframe']} Minute) --\n"
	  		end

  		when tvData['tickerType'] == 'forex'
  			# execute oanda
  		end
  	end
  end

  def self.krakenMarketOrder(tvData, apiKey, secretKey) #entry
  	# only create order if within 'trail' of last set order of this 'type' -> limit/market and account less than definedRisk from TV
  	unitsToTrade = xpercentForTradeFromTimeframe(tvData, apiKey, secretKey)

  	if unitsToTrade > 0 
  		# unitsWithScale
  		Thread.pass
  		case true
  		when tvData['tickerType'] == 'crypto'
				pairCall = publicPair(tvData, apiKey, secretKey)
				Thread.pass
				resultKey = pairCall['result'].keys.first
				baseTicker = pairCall['result'][resultKey]['base']
	  		Thread.pass
				currentAllocation = krakenBalance(apiKey, secretKey)
				Thread.pass
				tickerInfoCall = tickerInfo(baseTicker, apiKey, secretKey)
				accountTotal = tickerInfoCall['result']['eb'].to_f

				currentRisk = (currentAllocation['result'][baseTicker].to_f/accountTotal) * 100
				if (currentRisk <= tvData['maxRisk'].to_f)
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
				    "volume" 		=> "#{unitsFiltered}",
				    "close[ordertype]" => "take-profit-limit",
				    "close[price]" 		=> (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['maxProfit'].to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['maxProfit'].to_f))))).round(1).to_s,
				    "close[price2]" 	=> (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['maxProfit'].to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['maxProfit'].to_f))))).round(1).to_s,
				  }

				  Thread.pass
					# averageOfPricesOpen = (pullPrices&.sum/pullPrices&.count)
			  	if tvData['direction'] == 'buy'
					  requestK = krakenRequest('/0/private/AddOrder', orderParams, apiKey, secretKey)
			  	end

				  if tvData['direction'] == 'sell'
					  requestK = krakenRequest('/0/private/AddOrder', orderParams, apiKey, secretKey)
				  end

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

  		when tvData['tickerType'] == 'forex'
  			# execute oanda
  		end
  	end
  end

  def self.xpercentForTradeFromTimeframe(tvData, apiKey, secretKey)
  	# hard coded min for bitcoin
  	currentPrice = tvData['currentPrice'].to_f
  	
  	if tvData['tickerType'] == 'crypto' && tvData['broker'] == 'kraken'
  		# add opentrades costs to calculation for maxRisk
  		Thread.pass
  		requestK = krakenBalance(apiKey, secretKey)
  		Thread.pass
  		accountBalance = requestK['result']['ZUSD'].to_f
  	end
  	
    case true
  	when tvData['timeframe'] == '15'
  		#need to make for each pair -> currently hard coded to bitcoin minimum
  		tvData['tickerType'] == 'crypto' ? ((tvData['perEntry'].to_f * 0.01) * accountBalance).to_f > 3 ? ((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f : nil
  	when tvData['timeframe'] == '30'
  		tvData['tickerType'] == 'crypto' ? ((tvData['perEntry'].to_f * 0.01) * accountBalance).to_f > 3 ? ((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f : nil
  	when tvData['timeframe'] == '60'
  		tvData['tickerType'] == 'crypto' ? ((tvData['perEntry'].to_f * 0.01) * accountBalance).to_f > 3 ? ((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f : nil
  	when tvData['timeframe'] == '120'
  		tvData['tickerType'] == 'crypto' ? ((tvData['perEntry'].to_f * 0.01) * accountBalance).to_f > 3 ? ((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f : nil
  	end
  end
  
  # def self.createTakeProfitOrder(tvData)
  # 	xpercentForTradeFromTimeframe
  #   routeToKraken = "/0/private/Balance"
  #   krakenRequest(routeToKraken,{}, apiKey, secretKey)
  # end

end


