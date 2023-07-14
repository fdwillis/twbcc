class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.killType(tvData, apiKey = nil, secretKey = nil)

    if tvData['broker'] == 'OANDA'
      @userX = User.find_by(oandaToken: apiKey)
      @openTrades = @userX.trades.where(broker: tvData['broker'], finalTakeProfit:nil)
      @traderFound = @userX

      @traderFound.oandaList.split(',').each do |accountID|
        requestP = Oanda.oandaPendingOrders(apiKey, accountID)
        if tvData['direction'] == 'sell'


          if tvData['killType'] == 'all'
            ordersToKill = requestP['orders'].reject{|d|!d['units'].to_f.negative?}
            ordersToKill.each do |oandaData|
              cancel = Oanda.oandaCancel(apiKey, secretKey, oandaData['id'])
              Trade.find_by(uuid: oandaData['id']).destroy!
            end
          elsif tvData['killType'] == 'profit'
          end
        end

        if tvData['direction'] == 'buy'
          if tvData['killType'] == 'all'
            ordersToKill = requestP['orders'].reject{|d|!d['units'].to_f.positive?}
            ordersToKill.each do |oandaData|
              cancel = Oanda.oandaCancel(apiKey, secretKey, oandaData['id'])
              Trade.find_by(uuid: oandaData['id']).destroy!
            end
          elsif tvData['killType'] == 'profit'
          end
        end
      end


      # killall 
      # killprofitable

    elsif tvData['broker'] == 'TRADIER'
    end

    puts "\n-- KILL COMPLETE --\n"
  end

  def self.trailStop(tvData, apiKey = nil, secretKey = nil)
    if tvData['broker'] == 'OANDA'
      @userX = User.find_by(oandaToken: apiKey)
      @openTrades = @userX.trades.where(broker: 'OANDA', finalTakeProfit:nil, direction: tvData['direction'] == 'sell' ? 'buy' : 'sell')
      @traderFound = @userX
    elsif tvData['broker'] == 'TRADIER'
    end

    puts "\n-- Current Price: #{tvData['currentPrice'].to_f} --\n"
    # update trade status
    if @openTrades.present? && @openTrades.size > 0
      @openTrades.each do |trade|
        if trade&.broker == 'OANDA'
          requestK = Oanda.oandaOrder(apiKey, secretKey, trade.uuid)
          
          if requestK['order']['state'] == 'CANCELLED'
            trade.destroy!
          elsif requestK['order']['state'] == 'PENDING'
            trade.update(status: 'open')
          elsif requestK['order']['state'] == 'FILLED'
            trade.update(status: 'closed')
          end
        elsif trade&.broker == 'TRADIER'
        end
      end
    end
    # pull closed/filled bot trades
    if tvData['broker'] == 'OANDA'
      afterUpdates =  @userX.trades.where(status: 'closed', broker: 'OANDA', finalTakeProfit: nil, direction: tvData['direction'] == 'sell' ? 'buy' : 'sell')
    elsif tvData['broker'] == 'TRADIER'
    end


    # protect closed/filled bot trades
    if afterUpdates.present? && afterUpdates.size > 0
      afterUpdates.each do |tradeX|
        puts "\n-- Starting For #{tradeX.uuid} --\n"
        if tradeX&.broker == 'OANDA'
          requestExecution = Oanda.oandaOrder(apiKey, secretKey, tradeX.uuid)
          @requestOriginalE = Oanda.oandaTrade(apiKey, secretKey, requestExecution['order']['fillingTransactionID'])
          
          originalPrice = @requestOriginalE['trade']['price'].present? ? @requestOriginalE['trade']['price'].to_f : 0
          originalVolume = @requestOriginalE['trade']['initialUnits'].to_f
        elsif tradeX&.broker == 'TRADIER'
        end

        profitTrigger = originalPrice * (0.01 * @traderFound&.profitTrigger)
        volumeTallyForTradex = 0
        openProfitCount = 0

        if tradeX&.broker == 'OANDA'
          profitTriggerPassed = (originalPrice + profitTrigger).round(5).to_f
        elsif tradeX&.broker == 'TRADIER'
        end

        if tradeX&.broker == 'OANDA'
          oandaOrderParams = {
            'stopLoss' => {
              'distance' => (tvData['type'] == 'sellStop' ? (((0.01 * tvData['trail'].to_f) *  tvData['currentPrice'].to_f) + tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f)) : (tvData['currentPrice'].to_f) - ( tvData['currentPrice'].to_f - ((0.01 * tvData['trail'].to_f) *  tvData['currentPrice'].to_f))).round(3),
            }
          }
        end

        if  @requestOriginalE['trade']['unrealizedPL'].to_f > 0
          if @requestOriginalE['trade']['currentUnits'].to_f.positive?
            if tvData['direction'] == 'sell'
              if tradeX.take_profits.size == 0
                if  tvData['broker'] == 'OANDA'
                
                  # @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)
                  @protectTrade = Oanda.oandaTrail(tvData, @requestOriginalE, apiKey, secretKey, tradeX)
                  
                  if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                    puts 	"\n-- Taking Profit #{@protectTrade['orderCreateTransaction']['id']} --\n"
                  end

                elsif tvData['broker'] == 'TRADIER'
                end
              else

                tradeX.take_profits.each do |profitTrade|
                  if  tvData['broker'] == 'OANDA'
                    requestProfitTradex = Oanda.oandaOrder(apiKey, secretKey, profitTrade.uuid)

                    if requestProfitTradex['order']['state'] == 'FILLED'
                      profitTrade.update(status: 'closed')
                    elsif requestProfitTradex['order']['state'] == 'PENDING'
                      profitTrade.update(status: 'open')
                    elsif requestProfitTradex['order']['state'] == 'CANCELLED'
                      profitTrade.update(status: 'canceled')
                    end
                    volumeForProfit = requestProfitTradex['order']['units'].to_f
                    priceToBeat = requestProfitTradex['order']['price'].to_f
                  elsif tvData['broker'] == 'TRADIER'
                  end
                  
                  if profitTrade.status == 'open' # or other status from oanda/alpaca
                    volumeTallyForTradex += volumeForProfit
                    openProfitCount += 1
                    
                    if  tvData['broker'] == 'OANDA'
                      if @requestOriginalE['trade']['currentUnits'].to_f > 0 && @requestOriginalE['trade']['unrealizedPL'].to_f > 0
                        cancel = Oanda.oandaCancel(apiKey, secretKey, profitTrade.uuid)
                        puts "\n-- Old Take Profit Canceled --\n"
                        # @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)
                        @protectTrade = Oanda.oandaTrail(tvData, @requestOriginalE, apiKey, secretKey, tradeX)
                        
                        if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                          puts  "\n-- Repainting Take Profit #{@protectTrade['orderCreateTransaction']['id']} --\n"
                        end
                        profitTrade.destroy!
                        break
                      end

                    elsif tvData['broker'] == 'TRADIER'
                    end
                  elsif profitTrade.status == 'closed' # or other status from oanda/alpaca
                    volumeTallyForTradex += volumeForProfit
                  elsif profitTrade.status == 'canceled' # or other status from oanda/alpaca
                    puts "\n-- Removing Canceled Order #{profitTrade.uuid} --\n"
                    profitTrade.destroy!
                    break
                  end
                end

                if volumeTallyForTradex < originalVolume
                  if openProfitCount == 0
                    if tvData['broker'] == 'OANDA'
                      # @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)
                      @protectTrade = Oanda.oandaTrail(tvData, @requestOriginalE, apiKey, secretKey, tradeX)
                      
                      if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                        puts  "\n-- Additional Take Profit #{@protectTrade['orderCreateTransaction']['id']} --\n"
                      end

                    elsif tvData['broker'] == 'TRADIER'
                    end
                  else
                    puts "\n-- Waiting To Close Open Take Profit --\n"
                  end
                else
                  if tvData['broker'] == 'OANDA'
                    checkFill = Oanda.oandaOrder(apiKey, secretKey, trade.uuid)
                  
                    if checkFill['order']['state'] == 'PENDING'
                      tradeX.update(finalTakeProfit: nil)
                    elsif checkFill['order']['state'] == 'FILLED'
                      tradeX.update(finalTakeProfit:  tradeX.take_profits.last.uuid)
                      tradeX.take_profits.last.update(status: 'closed')
                    end
                  elsif tvData['broker'] == 'TRADIER'
                  end
                end
              end
            end
          elsif @requestOriginalE['trade']['currentUnits'].to_f.negative?
            if tvData['direction'] == 'buy'

              if tradeX.take_profits.size == 0
                  
                if tvData['broker'] == 'OANDA'
                  # @protectTrade = Oanda.oandaTrail(tvData, requestExecution, apiKey, secretKey, tradeX)
                  @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)
                  
                  if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                    puts  "\n-- Taking Profit #{@protectTrade['orderCreateTransaction']['id']} --\n"
                  end

                elsif tvData['broker'] == 'TRADIER'
                end
              else

                tradeX.take_profits.each do |profitTrade|
                  if tvData['broker'] == 'OANDA'
                    requestProfitTradex = Oanda.oandaOrder(apiKey, secretKey, profitTrade.uuid)

                    if requestProfitTradex['order']['state'] == 'FILLED'
                      profitTrade.update(status: 'closed')
                    elsif requestProfitTradex['order']['state'] == 'PENDING'
                      profitTrade.update(status: 'open')
                    elsif requestProfitTradex['order']['state'] == 'CANCELLED'
                      profitTrade.update(status: 'canceled')
                    end
                    volumeForProfit = requestProfitTradex['order']['units'].to_f
                    priceToBeat = requestProfitTradex['order']['price'].to_f
                  elsif tvData['broker'] == 'TRADIER'
                  end

                  if profitTrade.status == 'open' # or other status from oanda/alpaca
                    volumeTallyForTradex += volumeForProfit
                    openProfitCount += 1

                    if tvData['broker'] == 'OANDA'
                      if @requestOriginalE['trade']['currentUnits'].to_f < 0 && @requestOriginalE['trade']['unrealizedPL'].to_f > 0
                        cancel = Oanda.oandaCancel(apiKey, secretKey, profitTrade.uuid)
                        profitTrade.destroy!
                        puts "\n-- Old Take Profit Canceled --\n"
                        # @protectTrade = Oanda.oandaTrail(tvData, requestExecution, apiKey, secretKey, tradeX)
                        @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)
                        
                        if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                          puts  "\n-- Repainting Take Profit #{@protectTrade['orderCreateTransaction']['id']} --\n"
                        end
                      end
                    elsif tvData['broker'] == 'TRADIER'
                    end
                  elsif profitTrade.status == 'closed' # or other status from oanda/alpaca
                    volumeTallyForTradex += volumeForProfit
                  elsif profitTrade.status == 'canceled' # or other status from oanda/alpaca
                    puts "\n-- Removing Canceled Order #{profitTrade.uuid} --\n"
                    profitTrade.destroy!
                    break
                  end
                end

                if volumeTallyForTradex > originalVolume
                  if openProfitCount == 0
                    if tvData['broker'] == 'OANDA'
                      # @protectTrade = Oanda.oandaTrail(tvData, requestExecution, apiKey, secretKey, tradeX)
                      if @requestOriginalE['trade']['currentUnits'].to_f < 0 && @requestOriginalE['trade']['unrealizedPL'].to_f > 0
                        @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)

                        if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                          puts  "\n-- Additional Take Profit #{@protectTrade['orderCreateTransaction']['id']} --\n"
                        end
                      end
                    elsif tvData['broker'] == 'TRADIER'
                    end
                  else
                    puts "\n-- Waiting To Close Open Take Profit --\n"
                  end
                else
                  if tvData['broker'] == 'OANDA'
                    checkFill = Oanda.oandaOrder(apiKey, secretKey, trade.uuid)
                    if checkFill['order']['state'] == 'PENDING'
                      tradeX.update(finalTakeProfit: nil)
                    elsif checkFill['order']['state'] == 'FILLED'
                      tradeX.update(finalTakeProfit:  tradeX.take_profits.last.uuid)
                      tradeX.take_profits.last.update(status: 'closed')
                    end
                  elsif tvData['broker'] == 'TRADIER'
                  end
                end

              end
            end
          end
        else
          if @requestOriginalE['trade']['currentUnits'].to_f.abs == 0
            tradeX.update(finalTakeProfit: tradeX.take_profits.present? ? tradeX.take_profits.last.uuid : 'closed')
          else
            puts "\n-- Waiting For Profit --\n"
          end
        end
      end
    end

    puts 'Done Checking Profit'
  end

  def self.newEntry(tvData, apiKey = nil, secretKey = nil)
    # if allowMarketOrder -> market order
    # if entries.count > 0 -> limit order
    currentFilledListToSum =  @traderFound&.trades

    if tvData['broker'] == 'OANDA'
      @traderFound = User.find_by(oandaToken: apiKey)
    elsif tvData['broker'] == 'TRADIER'
      @traderFound = User.find_by(tradierToken: apiKey)
    end



    # variables
    orderforMulti = 0

    if tvData['broker'] == 'OANDA'
      @amountToRisk = Oanda.oandaRisk(tvData, apiKey, secretKey)

      oandaAccount = Oanda.oandaAccount(apiKey, secretKey)
      cleanTickers = oandaAccount['account']['positions'].map { |d| d['instrument'].tr!('_', '') }

      foundTickerPosition = oandaAccount['account']['positions'].reject { |d| d['instrument'] != tvData['ticker'] }.first
      foundTickerOrders = oandaAccount['account']['orders'].reject { |d| d['instrument'] != "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}" }

      marginUsed = foundTickerPosition.present? && foundTickerPosition['marginUsed'].present? ? foundTickerPosition['marginUsed'].to_f : 0

      openOrders = (oandaAccount['account']['marginRate'].to_f * foundTickerOrders.map { |d| d['units'].to_i }.sum)
      openOrdersPending = openOrders
      accountBalance = ((marginUsed + openOrders) + oandaAccount['account']['marginAvailable'].to_f)

      orderforMulti += @traderFound&.allowMarketOrder == 'true' ? 1 : 0
      tvData['entries'].reject(&:blank?).size > 0 ? orderforMulti += tvData['entries'].reject(&:blank?).size : orderforMulti += 0
    elsif tvData['broker'] == 'TRADIER'
    end

    
    if tvData['broker'] == 'OANDA'
     @currentRisk = calculateRiskAfterTrade(marginUsed,openOrdersPending, (@amountToRisk * orderforMulti),  accountBalance)
    elsif tvData['broker'] == 'TRADIER'
    end

    # ticker specific

    if tvData['ticker'] == 'BTCUSD'
      @unitsFiltered = (@unitsToTrade > 0.0001 ? @unitsToTrade : 0.0001)
    end
    
    if @currentRisk.round(2) < @traderFound&.maxRisk && @currentRisk.round(2) >= 0
      # market order
      if @traderFound&.allowMarketOrder == 'true'
        # set order params

        if tvData['broker'] == 'OANDA'
          oandaOrderParams = {
            'order' => {
              'units' => tvData['direction'] == 'buy' ? (@amountToRisk == oandaAccount['account']['marginRate'].to_f ? 1 : @amountToRisk.round).to_s : (@amountToRisk == oandaAccount['account']['marginRate'].to_f ? -1 : -@amountToRisk.round).to_s,
              'instrument' => "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}",
              'timeInForce' => 'FOK',
              'type' => 'MARKET',
              'positionFill' => 'DEFAULT'
            }
          }
        elsif tvData['broker'] == 'TRADIER'
        end

        # call order
        if tvData['direction'] == 'buy'

          if tvData['broker'] == 'OANDA'
            @requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
          elsif tvData['broker'] == 'TRADIER'
          end
        end

        # put order
        if tvData['direction'] == 'sell'

          if  tvData['broker'] == 'OANDA'
            @requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
          elsif tvData['broker'] == 'TRADIER'
          end
        end

        # update database with ID from @requestK

        if tvData['broker'] == 'OANDA'

          if @requestK.present? && !@requestK['orderCancelTransaction'].present?
            User.find_by(oandaToken: apiKey).trades.create(traderID: tvData['traderID'], uuid: @requestK['orderCreateTransaction']['id'], broker: tvData['broker'], direction: tvData['direction'], status: 'closed', cost: @requestK['orderFillTransaction']['tradeOpened']['initialMarginRequired'].to_f)
            @costForLimit = @requestK['orderFillTransaction']['tradeOpened']['initialMarginRequired'].to_f
            puts "\n-- #{tvData['broker']} Entry Submitted --\n"
            puts "\n-- Current Risk #{@currentRisk.round(2)} --\n"
          end
        elsif tvData['broker'] == 'TRADIER'
        end
      end

      # limit order
      if tvData['entries'].reject(&:blank?).size > 0
        tvData['entries'].reject(&:blank?).each do |entryPercentage|
          if tvData['broker'] == 'OANDA'
            priceToSet = (tvData['direction'] == 'sell' ? tvData['highPrice'].to_f + (tvData['highPrice'].to_f * (0.01 * entryPercentage.to_f)) : tvData['lowPrice'].to_f - (tvData['lowPrice'].to_f * (0.01 * entryPercentage.to_f))).round(5)
          elsif tvData['broker'] == 'TRADIER'
          end
          # set order params

          if tvData['broker'] == 'OANDA'
            oandaOrderParams = {
              'order' => {
                'price' => priceToSet.to_s,
                'units' => tvData['direction'] == 'buy' ? (@amountToRisk == oandaAccount['account']['marginRate'].to_f ? 1 : @amountToRisk.round).to_s : (@amountToRisk == oandaAccount['account']['marginRate'].to_f ? -1 : -@amountToRisk.round).to_s,
                'instrument' => "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}",
                'timeInForce' => 'GTC',
                'type' => 'LIMIT',
                'positionFill' => 'DEFAULT'
              }
            }
          elsif tvData['broker'] == 'TRADIER'

          end
          # call order
          if tvData['direction'] == 'buy'

            if tvData['broker'] == 'OANDA'
              requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
            elsif tvData['broker'] == 'TRADIER'
            end
          end
          # put order
          if tvData['direction'] == 'sell'

            if tvData['broker'] == 'OANDA'
              requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
            elsif tvData['broker'] == 'TRADIER'
            end
          end

          # update database with ID from requestK

          if tvData['broker'] == 'OANDA'

            if  requestK.present? && !requestK['orderCancelTransaction'].present?
              User.find_by(oandaToken: apiKey).trades.create(traderID: tvData['traderID'], uuid: requestK['orderCreateTransaction']['id'], broker: tvData['broker'], direction: tvData['direction'], status: 'open', cost: @costForLimit)
              puts "\n-- #{tvData['broker']} Entry Submitted --\n"
              puts "\n-- Current Risk #{@currentRisk.round(2)} --\n"
            else
              puts "\n-- NOTHING --\n"
            end
          elsif tvData['broker'] == 'TRADIER'

          end
        end
      else
        puts "\n-- No Limit Orders Set --\n"
      end

    else
      puts "\n-- Max Risk Met (#{tvData['timeframe']} Minute) --\n"
      puts "\n-- Trader #{@traderFound.uuid} --\n"
      puts "\n-- Current Risk (#{@currentRisk.round(2)}%) --\n"
      puts "\n-- Trader #{@traderFound.uuid} --\n"
    end
  end

  def self.calculateRiskAfterTrade(filledOrders,openOrdersPending, amountToRisk, accountBalance)
    ((filledOrders + openOrdersPending ) / accountBalance) * 100
  end

  # combine limit and market into one 'entry' call with logic to determine wich
end
