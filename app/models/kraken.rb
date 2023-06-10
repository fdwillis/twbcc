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
  
  def self.krakenTrades(filledOrNot = nil, page = nil, apiKey, secretKey)
  	buildTrades = []
    routeToKraken = "/0/private/TradesHistory"

    if page.present? && page.to_i > 1
    	orderParams = {
		    "trades" 			=> true,
		    "ofs" 			=> (page - 1) * 50,
		  }
	    requestK = krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
    else
	    orderParams = {
		    "trades" 			=> true,
		  }	
	    requestK = krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
		end

    requestK
  end

  def self.krakenTrade(tradeID, apiKey, secretKey)
  	
    routeToKraken = "/0/private/QueryTrades"
    orderParams = {
	    "txid" 			=> tradeID,
	    "trades" 			=> true,
	  }	
    krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
  end

  def self.krakenOrder(orderID, apiKey, secretKey)
  	
    routeToKraken = "/0/private/QueryOrders"
    orderParams = {
	    "txid" 			=> orderID,
	    "trades" 			=> true,
	  }	
    krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
  end

  def self.krakenTrailOrStop(tvData,tradeInfo, apiKey, secretKey)
  	# edit order
  	#update ClosedTrade Model with protection or info if needed
    routeToKraken = "/0/private/AddOrder"

    orderParams = {
	    "pair" 			=> tradeInfo['descr']['pair'],
	    "ordertype" => tradeInfo['descr']['ordertype'],
	    "type" 			=> tradeInfo['descr']['type'],
	    "price" 		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
	    "price2"		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * (tvData['trail'].to_f)))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * (tvData['trail'].to_f)))).round(1)).to_s,
	    "volume" 		=> tradeInfo['vol']
	  }
	  Thread.pass
	  # remove all trailing first
    krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
  end

  def self.krakenTrailStop(tvData, apiKey, secretKey)
  	# if in profit by less than tvData['trail'] -> set to break even
  	# if in profit by more than tvData['trail'] -> set to trail
  	# if not in profit -> hold

  	takeProfitTrades = Kraken.krakenPendingTrades(apiKey, secretKey)
  	takeProfitTradesKeys = takeProfitTrades.keys

  	filterTakeProfitKeys = []

  	takeProfitTradesKeys.each do |keyID|
  		if takeProfitTrades[keyID]['descr']['ordertype'] == 'take-profit-limit'
  			filterTakeProfitKeys << keyID
  		end
  	end

  	if filterTakeProfitKeys.size > 0
	  	filterTakeProfitKeys.each do |tradeID|

		  	Thread.pass
	  		requestK = krakenOrder(tradeID, apiKey, secretKey)
	  		if requestK.present? && requestK['result'].present?

	  			afterSleep = requestK['result'][tradeID]

					case true
					when tvData['direction'] == 'sell'
						@nextTakeProfit = (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1).to_f
					when tvData['direction'] == 'buy'
						@nextTakeProfit = (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1).to_f
					end
					
					Thread.pass

					if tvData['direction'] == 'sell'
	  				if (@nextTakeProfit > (afterSleep['descr']['price2'].to_f))
	  					@protectTrade = krakenTrailOrStop(tvData,afterSleep, apiKey, secretKey)
						  puts "\n-- Setting Take Profit --\n"
						  Thread.pass
						else
						  puts "\n-- Waiting For More Profit --\n"
		  			end
	  			end

	  			if tvData['direction'] == 'buy'
		  			if (@nextTakeProfit < (afterSleep['descr']['price2'].to_f))
		  				@protectTrade = krakenTrailOrStop(tvData,afterSleep, apiKey, secretKey)
						  puts "\n-- Setting Take Profit --\n"
						  Thread.pass
						else
						  puts "\n-- Waiting For More Profit --\n"
		  			end
	  			end

			  	Thread.pass

	  			if @protectTrade.present? && @protectTrade['result'].present?
	  				orderParams = {
					    "txid" 			=> tradeID,
					  }
				  	routeToKraken = "/0/private/CancelOrder"
				  	Thread.pass
				  	cancel = krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
				  	Thread.pass
				  	puts "\n-- Profit Repainted #{@protectTrade} --\n"
			 		end
		  	end
		  end
		else
			puts "No Positions Triggered For Profit"
		end
  end

  def self.krakenLimitOrder(tvData, apiKey, secretKey) #entry
  	
  	# only create order if within 'trail' of last set order of this 'type' -> limit/market and account less than definedRisk from TV
  	unitsToTrade = xpercentForTradeFromTimeframe(tvData, apiKey, secretKey)
  	if unitsToTrade > 0 
  		# unitsWithScale
  		case true
  		when tvData['tickerType'] == 'crypto'
		  	Thread.pass
				pairCall = publicPair(tvData, apiKey, secretKey)
				Thread.pass
				resultKey = pairCall['result'].keys.first
				baseTicker = pairCall['result'][resultKey]['base']
				currentAllocation = krakenBalance(apiKey, secretKey)['result'][baseTicker].to_f
				Thread.pass
				tickerInfoCall = tickerInfo(baseTicker, apiKey, secretKey)
				Thread.pass
				accountTotal = tickerInfoCall['result']['eb'].to_f

				currentRisk = (currentAllocation/accountTotal) * 100
				
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
						    "close[price]" 		=> (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['profitBy'].to_f + entryPercentage.to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['profitBy'].to_f + entryPercentage.to_f))))).round(1).to_s,
						    "close[price2]" 		=>  (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['profitBy'].to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['profitBy'].to_f))))).round(1).to_s,
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
								  firstMake = ClosedTrade.create(entry: requestK['result']['txid'][0], entryStatus: 'open')
								  getOrder = krakenOrder(requestK['result']['txid'][0], apiKey, secretKey)['result']
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
  		case true
  		when tvData['tickerType'] == 'crypto'
	  		Thread.pass
				pairCall = publicPair(tvData, apiKey, secretKey)
				Thread.pass
				resultKey = pairCall['result'].keys.first
				baseTicker = pairCall['result'][resultKey]['base']
				currentAllocation = krakenBalance(apiKey, secretKey)['result'][baseTicker].to_f
				Thread.pass
				tickerInfoCall = tickerInfo(baseTicker, apiKey, secretKey)
				Thread.pass
				accountTotal = tickerInfoCall['result']['eb'].to_f

				currentRisk = (currentAllocation/accountTotal) * 100
				if (currentRisk <= tvData['maxRisk'].to_f)
	  			priceToSet = (tvData['currentPrice']).to_f.round(1)

	  			case true
			    when tvData['ticker'] == 'BTCUSD'
			    	unitsFiltered = (unitsToTrade > 0.0001 ? unitsToTrade : 0.0001)
			    when tvData['ticker'] == 'PAXGUSD'
			    	unitsFiltered = (unitsToTrade > 0.003 ? unitsToTrade : 0.003)
			    end
+
	  			orderParams = {
				    "pair" 			=> tvData['ticker'],
				    "type" 			=> tvData['direction'],
				    "ordertype" => "market",
				    "volume" 		=> "#{unitsFiltered}",
				    "close[ordertype]" => "take-profit-limit",
				    "close[price]" 		=> (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['profitBy'].to_f + tvData['profitBy'].to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['profitBy'].to_f + tvData['profitBy'].to_f))))).round(1).to_s,
				    "close[price2]" 		=>  (tvData['direction'] == 'sell' ? priceToSet - (priceToSet * (0.01 * ((tvData['profitBy'].to_f)))) : priceToSet + (priceToSet * (0.01 * ((tvData['profitBy'].to_f))))).round(1).to_s,
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
						  firstMake = ClosedTrade.create(entry: requestK['result']['txid'][0], entryStatus: 'open')
						  getOrder = krakenOrder(requestK['result']['txid'][0], apiKey, secretKey)['result']
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

  		when tvData['tickerType'] == 'forex'
  			# execute oanda
  		end
  	end
  end

  def self.xpercentForTradeFromTimeframe(tvData, apiKey, secretKey)
  	#make work for kraken and oanda

  	currentPrice = tvData['currentPrice'].to_f
  	
  	if tvData['tickerType'] == 'crypto' && tvData['broker'] == 'kraken'
  		requestK = krakenBalance(apiKey, secretKey)
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
  #   krakenRequest(routeToKraken,{}, apiKey, secretKey)
  # end

end


