class ApplicationRecord < ActiveRecord::Base
	self.abstract_class = true

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
