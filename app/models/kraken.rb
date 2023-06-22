class Kraken < ApplicationRecord
	# self.abstract_class = true
	def self.get_kraken_signature(uri_path, api_nonce, api_sec, api_post, secretKey)
    api_sha256 = OpenSSL::Digest.new('sha256').digest("#{api_nonce}#{api_post}")
    api_hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha512'), Base64.decode64(secretKey), "#{uri_path}#{api_sha256}")
    Base64.strict_encode64(api_hmac)
  end

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
    orderParams = {
    	"trades" => true
    }
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

  def self.krakenTrailOrStop(tvData,tradeInfo, apiKey, secretKey, tradeX)
  	# FINAL TESTING
  	requestProfit = nil
  	if tvData['reduceBy'].present? && tvData['reduceBy'].to_f != 100
  		#  take tvData['reduceBy'] now
	    routeToKraken = "/0/private/AddOrder"

	    orderParams = {
		    "pair" 			=> tradeInfo['descr']['pair'],
		    "ordertype" => "stop-loss-limit",
		    "type" 			=> tvData['direction'],
		    "price" 		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
		    "price2" 		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
		    "volume" 		=> (tradeInfo['vol'].to_f * (0.01 * tvData['reduceBy'].to_f)) > 0.0001 ? "%.10f" % (tradeInfo['vol'].to_f * (0.01 * tvData['reduceBy'].to_f)) : "0.0001"
		  }
		  Thread.pass
	    requestProfit = krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
	  end

	  if tvData[  'reduceBy'].present? && tvData['reduceBy'].to_f == 100
	    routeToKraken1 = "/0/private/AddOrder"

	    orderParams1 = {
		    "pair" 			=> tradeInfo['descr']['pair'],
		    "ordertype" => "stop-loss-limit",
		    "type" 			=> tvData['direction'],
		    "price" 		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
		    "price2" 		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
		    "volume" 		=> tradeInfo['vol']
		  }
		  Thread.pass
	    requestProfit = krakenRequest(routeToKraken1, orderParams1, apiKey, secretKey)

	  end

		tradeX.take_profits.create!(uuid: requestProfit['result']['txid'][0], status: 'open', direction: tvData['direction'], broker: tvData['broker'], user_id: User.find_by(krakenLiveAPI: apiKey).id)
		requestProfit
  end

  def self.krakenTrailStop(tvData, apiKey, secretKey)
  	# if in profit by less than tvData['trail'] -> set to break even
  	# if in profit by more than tvData['trail'] -> set to trail
  	# if not in profit -> hold
		puts "\n-- Current Price: #{tvData['currentPrice'].to_f.round(1)} --\n"

		openTrades = User.find_by(krakenLiveAPI: apiKey).trades.where(status: 'open', broker: tvData['broker'])
		if openTrades.present? && openTrades.size > 0 
	  	openTrades.each do |trade| # go update known limit orders status
	  		Thread.pass
	  		requestK = krakenOrder(trade.uuid, apiKey, secretKey)
	  		if requestK['status'] == 'canceled'
	  			trade.destroy
	  		else
		  		trade.update(status: requestK['status'])
		  	end
	  	end
  	end
  	
  	# pull current pending orders for sync of database
  	afterUpdates = User.find_by(krakenLiveAPI: apiKey).trades.where(status: 'closed', broker: tvData['broker'], finalTakeProfit: nil)
  	
  	if afterUpdates.present? && afterUpdates.size > 0	
	  	afterUpdates.each do |tradeX|
			  Thread.pass
			  
	  		requestOriginalE = krakenOrder(tradeX.uuid, apiKey, secretKey)

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
				  			@protectTrade = krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey, tradeX)
				  			if @protectTrade.present? && @protectTrade['result']['txid'].present?
				  				puts 	"\n-- Taking Profit #{@protectTrade['result']['txid'][0]} --\n"
				  			end
			  			end
				  	else
				  		tradeX.take_profits.each do |profitTrade|
				  			Thread.pass
					  		requestProfitTradex = krakenOrder(profitTrade.uuid, apiKey, secretKey)
					  		profitTrade.update(status: requestProfitTradex['status'])

					  		if requestProfitTradex['status'] == 'open'
					  			volumeTallyForTradex += requestProfitTradex['vol'].to_f
				  				openProfitCount += 1
					  			
						  		if (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) >  requestProfitTradex['descr']['price2'].to_f + ((0.01 * tvData['trail'].to_f) * (requestProfitTradex['descr']['price2'].to_f).round(1).to_f)
						  			
						  			orderParams = {
									    "txid" 			=> profitTrade.uuid,
									  }
								  	routeToKraken = "/0/private/CancelOrder"
								  	Thread.pass
								  	cancel = krakenRequest(routeToKraken, orderParams, apiKey, secretKey)
								  	profitTrade.destroy
						  			puts "\n-- Old Take Profit Canceled --\n"
						  			Thread.pass
						  			@protectTrade = krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey, tradeX)
						  			if @protectTrade.present? && @protectTrade['result']['txid'].present?
						  				puts "\n-- Repainting Take Profit #{@protectTrade['result']['txid'][0]} --\n"
						  			end
						  		end
					  		elsif requestProfitTradex['status'] == 'closed'
						  		volumeTallyForTradex += requestProfitTradex['vol'].to_f
					  		elsif requestProfitTradex['status'] == 'canceled'
				  				puts "\n-- Removing Canceled Order #{profitTrade.uuid} --\n"
					  			profitTrade.destroy
					  			next
					  		end
					  		
				  		end
				  		
			  			Thread.pass
				  		if volumeTallyForTradex < requestOriginalE['vol'].to_f
				  			if openProfitCount == 0
					  			@protectTrade = krakenTrailOrStop(tvData,requestOriginalE, apiKey, secretKey, tradeX)
					  			if @protectTrade.present? && @protectTrade['result']['txid'].present?
					  				puts "\n-- Additional Take Profit #{@protectTrade['result']['txid'][0]} --\n"
					  			end
					  		else
					  				puts "\n-- Waiting To Close Open Take Profit --\n"
				  			end
				  		else
				  			checkFill = krakenOrder(tradeX.take_profits.last.uuid, apiKey, secretKey)
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

  

  def self.xpercentForTradeFromTimeframe(tvData, apiKey, secretKey)
  	# hard coded min for bitcoin
  	currentPrice = tvData['currentPrice'].to_f
  	
		Thread.pass
  	if tvData['tickerType'] == 'crypto' && tvData['broker'] == 'kraken'
  		# add opentrades costs to calculation for maxRisk
  		Thread.pass
  		requestK = krakenBalance(apiKey, secretKey)
			Thread.pass
  		accountBalance = requestK['result']['ZUSD'].to_f
  	end

  	((tvData['perEntry'].to_f * 0.01) * accountBalance).to_f > 3 ? ((tvData['perEntry'].to_f * 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f 
  end
  
  # def self.createTakeProfitOrder(tvData)
  # 	xpercentForTradeFromTimeframe
  #   routeToKraken = "/0/private/Balance"
  #   krakenRequest(routeToKraken,{}, apiKey, secretKey)
  # end

end


