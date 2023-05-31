class Crypto

  # Generate the Kraken API signature

	def self.get_kraken_signature(uri_path, api_nonce, api_sec, api_post)
	  api_sha256 = OpenSSL::Digest.new('sha256').digest("#{api_nonce}#{api_post}")
	  api_hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha512'), Base64.decode64(ENV['krakenTestSecret']), "#{uri_path}#{api_sha256}")
	  Base64.strict_encode64(api_hmac)
	end

	# Attaches auth headers and returns results of a POST request
	def self.krakenRequest(uri_path, orderParams = {})
	  api_nonce = (Time.now.to_f * 1000).to_i.to_s
	  post_data = orderParams.map { |key, value| "#{key}=#{value}" }.join('&')
    api_post = post_data.present? ? "nonce=#{api_nonce}&#{post_data}" : "nonce=#{api_nonce}"
	  api_signature = get_kraken_signature(uri_path, api_nonce, ENV['krakenTestSecret'], api_post)
	  
	  headers = {
	    "API-Key" => ENV['krakenTestAPI'],
	    "API-Sign" => api_signature
	  }

	  uri = URI("https://api.kraken.com" + uri_path)
	  req = Net::HTTP::Post.new(uri.path, headers)
	  req.set_form_data({ "nonce" => api_nonce }.merge(orderParams))

	  http = Net::HTTP.new(uri.host, uri.port)
	  http.use_ssl = true
	  response = http.request(req)
	  return Oj.load(response.body)
	end

	def self.krakenBalance
    routeToKraken = "/0/private/Balance"
    krakenRequest(routeToKraken)
  end

  def self.krakenTrades
    routeToKraken = "/0/private/OpenOrders"
    krakenRequest(routeToKraken)
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

  			orderParams = {
			    "pair" 			=> tvData['ticker'],
			    "type" 			=> tvData['direction'],
			    "ordertype" => "market",
			    "volume" 		=> "#{unitsToTrade}" 
			  }	

			  tradesToUpdate = krakenTrades['result']['open']
		  	keysForTrades = krakenTrades['result']['open'].keys

		  	pullPrices = []
		  	keysForTrades.each do |keyX|
		  		infoX = tradesToUpdate[keyX]
			  	if infoX['descr']['type'] == tvData['direction'] #and the same direction
				  	pullPrices << infoX['descr']['price'].to_f
			  	end
		  	end
				# averageOfPricesOpen = (pullPrices&.sum/pullPrices&.count)
			  if !keysForTrades.empty?
			  	if tvData['direction'] == 'buy' && (priceToSet < (pullPrices&.max + (pullPrices&.max.to_f * (0.01 * tvData['trail'].to_f))))
					  requestK = krakenRequest('/0/private/AddOrder', orderParams)
			  	end

				  if tvData['direction'] == 'sell' && (priceToSet > (pullPrices&.low - (pullPrices&.max.to_f * (0.01 * tvData['trail'].to_f))))
					  requestK = krakenRequest('/0/private/AddOrder', orderParams)
				  end
			  else
				  requestK = krakenRequest('/0/private/AddOrder', orderParams)
			  end

			  if requestK['error'][0].present? && requestK['error'][0].include?("Insufficient")
			  	puts "\n-- MORE CASH FOR ENTRIES --\n"
			  	return
			  end

			  if requestK['result']['txid'].present?
			  	puts "\n-- Kraken Entry Submitted --\n"
				end

  		when tvData['tickerType'] == 'forex'
  			# execute oanda
  		end
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
  			if tvData['direction'] == 'buy'
  				removePutOrders(tvData)
  			else
  				removeCallOrders(tvData)
  			end

  			priceToSet = (tvData['direction'] == 'sell' ? tvData['highPrice'].to_f + (tvData['highPrice'].to_f * (0.01 * tvData['trail'].to_f)) : tvData['lowPrice'].to_f - (tvData['lowPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)

  			orderParams = {
			    "pair" 			=> tvData['ticker'],
			    "type" 			=> tvData['direction'],
			    "ordertype" => "limit",
			    "price" 		=> priceToSet,
			    "volume" 		=> "#{unitsToTrade}" 
			  }

			  tradesToUpdate = krakenTrades['result']['open']
		  	keysForTrades = krakenTrades['result']['open'].keys

		  	pullPrices = []
		  	keysForTrades.each do |keyX|
		  		infoX = tradesToUpdate[keyX]
			  	if infoX['descr']['type'] == tvData['direction'] #and the same direction
				  	pullPrices << infoX['descr']['price'].to_f
			  	end
		  	end
				# averageOfPricesOpen = (pullPrices&.sum/pullPrices&.count)
			  # # Construct the request and print the result
			  if !keysForTrades.empty?
			  	if tvData['direction'] == 'buy' && (priceToSet < (pullPrices&.max + (pullPrices&.max.to_f * (0.01 * tvData['trail'].to_f))))
					  requestK = krakenRequest('/0/private/AddOrder', orderParams)
			  	end
			  	
				  if tvData['direction'] == 'sell' && (priceToSet > (pullPrices&.low - (pullPrices&.max.to_f * (0.01 * tvData['trail'].to_f))))
					  requestK = krakenRequest('/0/private/AddOrder', orderParams)
				  end
			  else
				  requestK = krakenRequest('/0/private/AddOrder', orderParams)
			  end

			  if requestK['error'][0].present? && requestK['error'][0].include?("Insufficient")
			  	puts "\n-- MORE CASH FOR ENTRIES --\n"
			  	return
				end

			  if requestK['result']['txid'].present?
			  	puts "\n-- Kraken Entry Submitted --\n"
			  end

  		when tvData['tickerType'] == 'forex'
  			# execute oanda
  		end
  	end
  end

  def self.removeCallOrders(tvData)
  	# a third
  	tradesToUpdate = krakenTrades['result']['open']
  	keysForTrades = krakenTrades['result']['open'].keys

  	#delete stop losses
  	keysForTrades.each do |keyX|
  		infoX = tradesToUpdate[keyX]
	  	if (infoX['descr']['ordertype'] == 'limit' || infoX['descr']['ordertype'] == 'market') && infoX['descr']['type'] != tvData['direction'] #and the same direction
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
  	tradesToUpdate = krakenTrades['result']['open']
  	keysForTrades = krakenTrades['result']['open'].keys

  	#delete stop losses
  	keysForTrades.each do |keyX|
  		infoX = tradesToUpdate[keyX]
	  	if (infoX['descr']['ordertype'] == 'limit' || infoX['descr']['ordertype'] == 'market') && infoX['descr']['type'] != tvData['direction'] #and the same direction
		  	orderParams = {
			    "txid" 			=> keyX,
			  }
		  	routeToKraken = "/0/private/CancelOrder"
		  	krakenRequest(routeToKraken, orderParams)
	  	end
  	end
	end

  def self.krakenTrailOrStop(tvData,tradeInfo)
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

  def self.removePendingTrails(tvData)
  	# a third
  	tradesToUpdate = krakenTrades['result']['open']
  	keysForTrades = krakenTrades['result']['open'].keys

  	#delete stop losses
  	keysForTrades.each do |keyX|
  		infoX = tradesToUpdate[keyX]
	  	if 	infoX['descr']['ordertype'] == 'stop-loss' &&
	  			infoX['descr']['type'] == tvData['direction'] #and the same direction
		  	orderParams = {
			    "txid" 			=> keyX,
			  }
		  	routeToKraken = "/0/private/CancelOrder"
		  	krakenRequest(routeToKraken, orderParams)
	  	end
  	end
	end

  def self.createTrailOrStopOrder(tvData)
  	# if in profit by less than tvData['trail'] -> set to break even
  	# if in profit by more than tvData['trail'] -> set to trail
  	# if not in profit -> hold

  	# removePendingTrails(tvData)

  	# a third
  	tradesToUpdate = krakenTrades['result']['open']
  	keysForTrades = krakenTrades['result']['open'].keys

  	tradesToTrail = (keysForTrades&.size - 1)


  	if tradesToTrail > 0
	  	keysForTrades[0..(tradesToTrail - 1)].each do |keyID|
	  		keyInfoX = tradesToUpdate[keyID]

		  	if 	keyInfoX['descr']['ordertype'] == 'stop-loss' &&
		  			keyInfoX['descr']['type'] == tvData['direction'] #and the same direction

		  			if tvData['direction'] == 'sell'
		  				@nextTakeProfit = (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1).to_f
		  				if (@nextTakeProfit > keyInfoX['descr']['price'].to_f)
		  					orderParams = {
							    "txid" 			=> keyID,
							  }
							  puts "\n-- Repainting New Profit --\n"
							else
							  puts "\n-- Waiting For More Profit --\n"
			  				next
			  			end
		  			end

		  			if tvData['direction'] == 'buy'
		  				@nextTakeProfit = (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1).to_f
			  			if (@nextTakeProfit < keyInfoX['descr']['price'].to_f)
			  				orderParams = {
							    "txid" 			=> keyID,
							  }
							  puts "\n-- Repainting New Profit --\n"
							else
							  puts "\n-- Waiting For More Profit --\n"
			  				next
			  			end
		  			end


			  	if orderParams.present?
				  	routeToKraken = "/0/private/CancelOrder"
				  	krakenRequest(routeToKraken, orderParams)
			  	end
		  	end

	  		case true
	  		when tvData['type'] == 'sellStop'
		  		if keyInfoX['descr']['type'] == 'buy'	
			  		changeOverProfit = ((keyInfoX['descr']['price'].to_f - (keyInfoX['descr']['price'].to_f * (0.01 * tvData['trail'].to_f))) - tvData['currentPrice'].to_f).round(1)
		  			
		  			if changeOverProfit > 0
		  				# if next stop loss proce is better then remove current trailings
				  		updatedTrade = krakenTrailOrStop(tvData,keyInfoX)
				  	else
				  		puts "\n\n-- Profit Below #{(keyInfoX['descr']['price'].to_f - (keyInfoX['descr']['price'].to_f * (0.01 * tvData['trail'].to_f))).round(1)}\nCurrently: #{tvData['currentPrice']}\nChange Till Profit: #{changeOverProfit.abs}\nOriginal Entry: #{keyInfoX['descr']['price'].to_f} --\n\n"
				  		updatedTrade = :noProfit
		  			end
	  			end
	  		when tvData['type'] == 'buyStop'
		  		if keyInfoX['descr']['type'] == 'sell'	
		  			changeOverProfit = (tvData['currentPrice'].to_f - (keyInfoX['descr']['price'].to_f + (keyInfoX['descr']['price'].to_f * (0.01 * tvData['trail'].to_f)))).round(1)
		  			
		  			if changeOverProfit > 0
		  				# if next stop loss proce is better then remove current trailings
				  		updatedTrade = krakenTrailOrStop(tvData,keyInfoX)
				  	else
				  		puts "\n\n-- Profit Above #{(keyInfoX['descr']['price'].to_f + (keyInfoX['descr']['price'].to_f * (0.01 * tvData['trail'].to_f))).round(1)}\nCurrently: #{tvData['currentPrice']}\nChange Till Profit: #{changeOverProfit.abs}\nOriginal Entry: #{keyInfoX['descr']['price'].to_f} --\n\n"
				  		updatedTrade = :noProfit
		  			end
	  			end
	  		end
	  	end
  	end
  end

  def self.xpercentForTradeFromTimeframe(tvData)
  	#make work for kraken and oanda

  	currentPrice = tvData['currentPrice'].to_f

  	if tvData['ticker'] == 'BTCUSD'
  		accountBalance = krakenBalance['ZUSD'].to_f
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