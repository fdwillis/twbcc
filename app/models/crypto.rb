class Crypto

  # Generate the Kraken API signature

	def self.get_kraken_signature(uri_path, api_nonce, api_sec, api_post)
	  api_sha256 = OpenSSL::Digest.new('sha256').digest("#{api_nonce}#{api_post}")
	  api_hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha512'), Base64.decode64(ENV['krakenTestSecret']), "#{uri_path}#{api_sha256}")
	  Base64.strict_encode64(api_hmac)
	end

	# Attaches auth headers and returns results of a POST request
	def self.kraken_request(uri_path, orderParams = {})
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
    kraken_request(routeToKraken)
  end

  def self.krakenTrades
    routeToKraken = "/0/private/TradesHistory"
    kraken_request(routeToKraken)
  end

  def self.updateTrade(tvData,tradeInfo)
    routeToKraken = "/0/private/EditOrder"
    orderParams = {
	    "pair" => tvData['ticker'],
	    "txid" => tradeInfo['ordertxid'],
	    "ordertype" => "stop-loss-limit",
	    "price" => tradeInfo["price"].to_f,
	    "price2" => tvData['type'] == 'sellStop' ? (tvData['lowPrice'].to_f + (tvData['lowPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['highPrice'].to_f - (tvData['highPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1),
	    "volume" => tradeInfo['vol'].to_f 
	  }
    kraken_request(routeToKraken, orderParams)
  end

  def self.createMarketOrder(tvData)
  	unitsToTrade = xpercentForTradeFromTimeframe(tvData)

  	if unitsToTrade > 0 
  		case true
  		when tvData['tickerType'] == 'crypto'
  			# execute kraken
  			orderParams = {
			    "pair" => tvData['ticker'],
			    "type" => tvData['type'] == 'newSell' ? "sell" : 'buy',
			    "ordertype" => "market",
			    "volume" => "#{unitsToTrade}" 
			  }
				
			  # # Construct the request and print the result
			  kraken_request('/0/private/AddOrder', orderParams)

  		when tvData['tickerType'] == 'forex'
  			# execute oanda
  		end
  	end
  end

  def self.createLimitOrder(tvData)
  	unitsToTrade = xpercentForTradeFromTimeframe(tvData)

  	if unitsToTrade > 0 
  		case true
  		when tvData['tickerType'] == 'crypto'
  			# execute kraken
  			orderParams = {
			    "pair" => tvData['ticker'],
			    "type" => tvData['type'] == 'newSell' ? "sell" : 'buy',
			    "ordertype" => "limit",
			    "price" => tvData['type'] == 'sellStop' ? tvData['lowPrice'].to_f + (tvData['lowPrice'].to_f * (0.01 * tvData['trail'].to_f)) : tvData['highPrice'].to_f - (tvData['highPrice'].to_f * (0.01 * tvData['trail'].to_f)),
			    "volume" => "#{unitsToTrade}" 
			  }
				
			  # # Construct the request and print the result
			  kraken_request('/0/private/AddOrder', orderParams)

  		when tvData['tickerType'] == 'forex'
  			# execute oanda
  		end
  	end
  end

  def self.createTrailOrStopOrder(tvData)
  	# if in profit by less than tvData['trail'] -> set to break even
  	# if in profit by more than tvData['trail'] -> set to trail
  	# if not in profit -> hold
  	keysForTrades = krakenTrades['result']['trades'].keys
  	tradesToUpdate = krakenTrades['result']['trades']

  	keysForTrades.each do |keyID|
  		keyInfoX = tradesToUpdate[keyID]

  		case true
  		when tvData['type'] == 'sellStop'
  			if keyInfoX['price'].to_f > (tvData['lowPrice'].to_f + (tvData['lowPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)
		  		updatedTrade = updateTrade(tvData,keyInfoX)
		  	else
		  		updatedTrade = :noProfit
  			end
  		when tvData['type'] == 'buyStop'
  			if keyInfoX['price'].to_f < (tvData['highPrice'].to_f - (tvData['highPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)
		  		updatedTrade = updateTrade(tvData,keyInfoX)
		  	else
		  		updatedTrade = :noProfit
  			end
  		end

	  	
	  	unless updatedTrade == :noProfit
	  		debugger
		  	unitsToTrade = xpercentForTradeFromTimeframe(tvData)
		  	if unitsToTrade > 0 
		  		case true
		  		when tvData['tickerType'] == 'crypto'
		  			# execute kraken
		  			orderParams = {
					    "pair" => tvData['ticker'],
					    "type" => tvData['type'] == 'sellStop' ? "buy" : 'sell',
					    "ordertype" => "limit",
					    "price" => tvData['type'] == 'sellStop' ? tvData['lowPrice'].to_f + (tvData['lowPrice'].to_f * (0.01 * tvData['trail'].to_f)) : tvData['highPrice'].to_f - (tvData['highPrice'].to_f * (0.01 * tvData['trail'].to_f)),
					    "close[price]" => tvData['type'] == 'sellStop' ? tvData['lowPrice'].to_f + (tvData['lowPrice'].to_f * (0.01 * tvData['trail'].to_f)) : tvData['highPrice'].to_f - (tvData['highPrice'].to_f * (0.01 * tvData['trail'].to_f)),
					    "close[price2]" => tvData['type'] == 'sellStop' ? tvData['lowPrice'].to_f + (tvData['lowPrice'].to_f * (0.01 * tvData['trail'].to_f)) : tvData['highPrice'].to_f - (tvData['highPrice'].to_f * (0.01 * tvData['trail'].to_f)),
					    "volume" => "#{unitsToTrade}" ,
					    "close[ordertype]" => "stop-loss-limit"
					  }
						
					  # # Construct the request and print the result
					  kraken_request('/0/private/AddOrder', orderParams)

		  		when tvData['tickerType'] == 'forex'
		  			# execute oanda
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
  #   kraken_request(routeToKraken)
  # end



end