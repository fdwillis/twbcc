class Crypto

 	@api_key = ENV['krakenLiveAPI']
	@api_sec = ENV['krakenLiveSecret']
  # Generate the Kraken API signature

	def self.get_kraken_signature(uri_path, api_nonce, api_sec, orderParams = {})
	  api_post = "nonce=#{api_nonce}"
	  api_sha256 = OpenSSL::Digest.new('sha256').digest("#{api_nonce}#{api_post}")
	  api_hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha512'), Base64.decode64(@api_sec), "#{uri_path}#{api_sha256}")
	  Base64.strict_encode64(api_hmac)
	end

	# Attaches auth headers and returns results of a POST request
	def self.kraken_request(uri_path, orderParams = {})
	  api_nonce = (Time.now.to_f * 1000).to_i.to_s
	  post_data = orderParams.map { |key, value| "#{key}=#{value}" }.join('&')
    api_post = "nonce=#{api_nonce}&#{post_data}"
	  api_signature = get_kraken_signature(uri_path, api_nonce, @api_sec, api_post)
	  
	  headers = {
	    'API-Key' => @api_key,
	    'API-Sign' => api_signature
	  }

	  uri = URI("https://api.kraken.com" + uri_path)
	  req = Net::HTTP::Post.new(uri.path, headers)
	  req.set_form_data({ "nonce" => api_nonce })
	  http = Net::HTTP.new(uri.host, uri.port)
	  http.use_ssl = true
	  response = http.request(req)
	  return Oj.load(response.body)['result']
	end

	def self.krakenBalance
    routeToKraken = "/0/private/Balance"
    kraken_request(routeToKraken)
  end

  def self.createMarketOrder(tvData)
  	unitsToTrade = xpercentForTradeFromTimeframe(tvData)

  	if unitsToTrade > 0 
  		case true
  		when tvData['tickerType'] == 'crypto'
  			# execute kraken
  			# order_params = {
			  #   "pair" => tvData['ticker'],
			  #   "type" => tvData['type'] == 'newSell' ? "sell" : 'buy',
			  #   "ordertype" => "market",
			  #   "volume" => unitsToTrade 
			  # }
			  
			  # # Construct the request and print the result
			  # resp = kraken_request('/0/private/AddOrder', order_params)
  		when tvData['tickerType'] == 'forex'
  			# execute oanda
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

  # def self.createLimitOrder(tvData)
  # 	xpercentForTradeFromTimeframe
  #   routeToKraken = "/0/private/Balance"
  #   kraken_request(routeToKraken)
  # end
  # def self.createTrailingOrder(tvData)
  # 	xpercentForTradeFromTimeframe
  #   routeToKraken = "/0/private/Balance"
  #   kraken_request(routeToKraken)
  # end
  # def self.createStopLossOrder(tvData)
  # 	xpercentForTradeFromTimeframe
  #   routeToKraken = "/0/private/Balance"
  #   kraken_request(routeToKraken)
  # end
  # def self.createTakeProfitOrder(tvData)
  # 	xpercentForTradeFromTimeframe
  #   routeToKraken = "/0/private/Balance"
  #   kraken_request(routeToKraken)
  # end



end