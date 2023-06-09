class Kraken
	# self.abstract_class = true
	def self.get_kraken_signature(uri_path, api_nonce, api_sec, api_post)
    api_sha256 = OpenSSL::Digest.new('sha256').digest("#{api_nonce}#{api_post}")
    api_hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha512'), Base64.decode64(ENV['krakenTestSecret']), "#{uri_path}#{api_sha256}")
    Base64.strict_encode64(api_hmac)
  end

  # Attaches auth headers and returns results of a POST request
  def self.krakenRequest(uri_path, orderParams = {})
    api_nonce = (Time.now.to_f * 1000).to_i.to_s
    post_data = orderParams.present? ? orderParams.map { |key, value| "#{key}=#{value}" }.join('&') : nil
    api_post = (orderParams.present? ? "nonce=#{api_nonce}&#{post_data}" : "nonce=#{api_nonce}")
    api_signature = get_kraken_signature(uri_path, api_nonce, ENV['krakenTestSecret'], api_post)
    
    headers = {
      "API-Key" => ENV['krakenTestAPI'],
      "API-Sign" => api_signature
    }
    
    uri = URI("https://api.kraken.com" + uri_path)
    req = Net::HTTP::Post.new(uri.path, headers)
    orderParams.present? ? req.set_form_data({ "nonce" => api_nonce }.merge(orderParams)) : req.set_form_data({ "nonce" => api_nonce })
    req.body = CGI.unescape(req.body)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(req)
    sleep 0.5
    Oj.load(response.body)
  end

	def self.krakenBalance
    routeToKraken = "/0/private/Balance"
    krakenRequest(routeToKraken)
  end

  def self.krakenPendingTrades
  	
    routeToKraken = "/0/private/OpenOrders"
    orderParams = {}
    requestK = krakenRequest(routeToKraken, orderParams)['result']['open']
    createPayload = JsonDatum.create(params: orderParams, payload: requestK)
    createPayload[:payload]
  end

  def self.tickerInfo(symbol)
  	
    routeToKraken = "/0/private/TradeBalance"
    orderParams = {
    	"asset" => symbol
    }

    requestK = krakenRequest(routeToKraken, orderParams)
  end

  def self.publicAsset(symbol)
  	
    routeToKraken = "/0/public/Assets"
    orderParams = {
    	"asset" => symbol
    }

    requestK = krakenRequest(routeToKraken, orderParams)
  end

  def self.publicAsset(symbol)
  	
    routeToKraken = "/0/public/Ticker"
    orderParams = {
    	"pair" => symbol
    }

    requestK = krakenRequest(routeToKraken, orderParams)
  end

  def self.publicPair(tvData)
    routeToKraken = "/0/public/AssetPairs"
    orderParams = {
    	"pair" => tvData['ticker']
    }

    requestK = krakenRequest(routeToKraken, orderParams)
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
	    "price2"		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * (tvData['trail'].to_f)))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * (tvData['trail'].to_f)))).round(1)).to_s,
	    "volume" 		=> volumeString.to_f > 0.0001 ? ("%.5f" % volumeToTake) : "0.0001"
	  }

	  # remove all trailing first
    krakenRequest(routeToKraken, orderParams)
  end

  def self.krakenTrailStop(tvData)
  	# if in profit by less than tvData['trail'] -> set to break even
  	# if in profit by more than tvData['trail'] -> set to trail
  	# if not in profit -> hold

  	takeProfitTrades = Kraken.krakenPendingTrades
  	takeProfitTradesKeys = takeProfitTrades.keys

  	filterTakeProfitKeys = []

  	takeProfitTradesKeys.each do |keyID|
  		if takeProfitTrades[keyID]['descr']['ordertype'] == 'take-profit-limit'
  			filterTakeProfitKeys << keyID
  		end
  	end

  	if filterTakeProfitKeys.size > 0
	  	filterTakeProfitKeys.each do |tradeID|

	  		requestK = krakenOrder(tradeID)
		  	Thread.pass
					debugger
	  		if requestK.present? && requestK['result'].present?

	  			afterSleep = requestK['result'][tradeID]

					case true
					when tvData['direction'] == 'sell'
						@nextTakeProfit = (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1).to_f
					when tvData['direction'] == 'buy'
						@nextTakeProfit = (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1).to_f
					end
					if tvData['direction'] == 'sell'
	  				if (@nextTakeProfit > (afterSleep['descr']['price2'].to_f))
						  puts "\n-- Setting Take Profit --\n"
	  					@protectTrade = krakenTrailOrStop(tvData,afterSleep)
	  					Thread.pass
						else
						  puts "\n-- Waiting For More Profit --\n"
		  			end
	  			end

	  			if tvData['direction'] == 'buy'

		  			if (@nextTakeProfit < (afterSleep['descr']['price2'].to_f))
						  puts "\n-- Setting Take Profit --\n"
		  				@protectTrade = krakenTrailOrStop(tvData,afterSleep)
		  				Thread.pass
						else
						  puts "\n-- Waiting For More Profit --\n"
		  			end
	  			end

	  			if @protectTrade.present? && @protectTrade['result'].present?
	  				orderParams = {
					    "txid" 			=> tradeID,
					  }
				  	routeToKraken = "/0/private/CancelOrder"
				  	cancel = krakenRequest(routeToKraken, orderParams)
				  	puts "\n-- Profit Repainted #{cancel} --\n"
			 		end
		  	end
		  end
		else
			puts "No Positions Triggered For Profit"
		end
  end

  def self.krakenLimitOrder(tvData) #entry
  	
  	# only create order if within 'trail' of last set order of this 'type' -> limit/market and account less than definedRisk from TV
  	unitsToTrade = xpercentForTradeFromTimeframe(tvData)
  	
  	if unitsToTrade > 0 
  		# unitsWithScale
  		case true
  		when tvData['tickerType'] == 'crypto'
		  	Thread.pass
				pairCall = publicPair(tvData)
				Thread.pass
				resultKey = pairCall['result'].keys.first
				baseTicker = pairCall['result'][resultKey]['base']
				currentAllocation = krakenBalance['result'][baseTicker].to_f
				Thread.pass
				sleep 0.5
				tickerInfoCall = tickerInfo(baseTicker)
				Thread.pass
				accountTotal = tickerInfoCall['result']['eb'].to_f

				currentRisk = (currentAllocation/accountTotal) * 100
				
				if (currentRisk <= tvData['maxRisk'].to_f)
			  	if tvData['entries'].size > 0
		  			tvData['entries'].each do |entryPercentage|

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
						    "close[price]" 		=> (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['profitBy'].to_f + entryPercentage.to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['profitBy'].to_f + entryPercentage.to_f))))).round(1).to_s,
						    "close[price2]" 		=>  (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['profitBy'].to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['profitBy'].to_f))))).round(1).to_s,
						  }

						  # if within maxRisk

						  Thread.pass
					  	if tvData['direction'] == 'buy' 
							  #remove current pendingOrder in this position
							  requestK = krakenRequest('/0/private/AddOrder', orderParams)
					  	end
					  	
						  if tvData['direction'] == 'sell'
							  #remove current pendingOrder in this position
							  requestK = krakenRequest('/0/private/AddOrder', orderParams)
						  end

						  if requestK.present? && requestK['result'].present?
							  if requestK['result']['txid'].present?
								  firstMake = ClosedTrade.create(entry: requestK['result']['txid'][0], entryStatus: 'open')
								  getOrder = krakenOrder(requestK['result']['txid'][0])['result']
								  firstMake.update(entryStatus: getOrder[requestK['result']['txid'][0]]['status'])
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
	  			puts "\n-- #{tvData['timeframe']} Max Risk Met --\n"
	  		end

  		when tvData['tickerType'] == 'forex'
  			# execute oanda
  		end
  	end
  end

  def self.krakenMarketOrder(tvData) #entry
  	# only create order if within 'trail' of last set order of this 'type' -> limit/market and account less than definedRisk from TV
  	unitsToTrade = xpercentForTradeFromTimeframe(tvData)

  	if unitsToTrade > 0 
  		# unitsWithScale
  		case true
  		when tvData['tickerType'] == 'crypto'
	  		Thread.pass
				pairCall = publicPair(tvData)
				Thread.pass
				resultKey = pairCall['result'].keys.first
				baseTicker = pairCall['result'][resultKey]['base']
				currentAllocation = krakenBalance['result'][baseTicker].to_f
				Thread.pass
				tickerInfoCall = tickerInfo(baseTicker)
				Thread.pass
				accountTotal = tickerInfoCall['result']['eb'].to_f

				currentRisk = (currentAllocation/accountTotal) * 100
				if (currentRisk <= tvData['maxRisk'].to_f)
			  	if tvData['entries'].size > 0
		  			tvData['entries'].each do |entryPercentage|	
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
						    "volume" 		=> "#{unitsFiltered}",
						    "close[ordertype]" => "take-profit-limit",
						    "close[price]" 		=> (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['profitBy'].to_f + entryPercentage.to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['profitBy'].to_f + entryPercentage.to_f))))).round(1).to_s,
						    "close[price2]" 		=>  (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['profitBy'].to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['profitBy'].to_f))))).round(1).to_s,
						  }

						  Thread.pass
							# averageOfPricesOpen = (pullPrices&.sum/pullPrices&.count)
					  	if tvData['direction'] == 'buy'
							  requestK = krakenRequest('/0/private/AddOrder', orderParams)
					  	end

						  if tvData['direction'] == 'sell'
							  requestK = krakenRequest('/0/private/AddOrder', orderParams)
						  end

						  if requestK.present? && requestK['result'].present?

								if requestK['result']['txid'].present?
								  firstMake = ClosedTrade.create(entry: requestK['result']['txid'][0], entryStatus: 'open')
								  getOrder = krakenOrder(requestK['result']['txid'][0])['result']
								  Thread.pass
								  firstMake.update(entryStatus: getOrder[requestK['result']['txid'][0]]['status'])
							  	puts "\n-- Kraken Entry Submitted --\n"
							  end
							else 
							  if requestK['error'][0].present? && requestK['error'][0].include?("Insufficient")
							  	puts "\n-- MORE CASH FOR ENTRIES --\n"
							  end
							end
						end
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
  		Thread.pass
  		accountBalance = requestK['result']['ZUSD'].to_f
  	end

  	if tvData['ticker'] == 'EURUSD'
  		# accountBalance = accountBalanceForOanda
  	end
    case true
  	when tvData['timeframe'] == '15'
  		#need to make for each pair -> currently hard coded to bitcoin minimum
  		tvData['tickerType'] == 'crypto' ? (((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f > 3 ? ((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f) : tvData['tickerType'] == 'forex' ? ((0.25* 0.01) * accountBalance / currentPrice).to_f.round : nil
  	when tvData['timeframe'] == '30'
  		tvData['tickerType'] == 'crypto' ? (((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f > 3 ? ((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f) : tvData['tickerType'] == 'forex' ? ((0.50* 0.01) * accountBalance / currentPrice).to_f.round : nil
  	when tvData['timeframe'] == '60'
  		tvData['tickerType'] == 'crypto' ? (((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f > 3 ? ((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f) : tvData['tickerType'] == 'forex' ? ((0.75* 0.01) * accountBalance / currentPrice).to_f.round : nil
  	when tvData['timeframe'] == '120'
  		tvData['tickerType'] == 'crypto' ? (((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f > 3 ? ((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f) : tvData['tickerType'] == 'forex' ? ((1* 0.01) * accountBalance / currentPrice).to_f.round : nil
  	end
  end
  
  # def self.createTakeProfitOrder(tvData)
  # 	xpercentForTradeFromTimeframe
  #   routeToKraken = "/0/private/Balance"
  #   krakenRequest(routeToKraken)
  # end

end


