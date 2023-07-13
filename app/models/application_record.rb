class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  INITALBALANCE = [
    {
      'uuid' => 'd57307d7',
      'initialDepopsit' => 169
    },
    {
      'uuid' => '728f1600',
      'initialDepopsit' => 1500
    },
    {
      'uuid' => 'dbff2194',
      'initialDepopsit' => 500
    }
  ].freeze

  def self.killPending(tvData, apiKey = nil, secretKey = nil)
    if tvData['broker'] == 'KRAKEN'
      @currentOpenAllocation = Kraken.pendingTrades(apiKey, secretKey)
      keys = @currentOpenAllocation.keys
      @currentOpenAllocation.each do |tradeX|
        next unless @currentOpenAllocation[tradeX[0]].present? && @currentOpenAllocation[tradeX[0]]['descr']['type'] == tvData['direction']

        krakenOrderParams = {
          'txid' => tradeX[0]
        }
        routeToKraken = '/0/private/CancelOrder'

        cancel = Kraken.request(routeToKraken, krakenOrderParams, apiKey, secretKey)
      end
    elsif tvData['broker'] == 'OANDA'
    elsif tvData['broker'] == 'TRADIER'
    end
  end

  def self.trailStop(tvData, apiKey = nil, secretKey = nil)
    if tvData['broker'] == 'KRAKEN'
      @userX = User.find_by(krakenLiveAPI: apiKey)
      @openTrades = @userX.trades.where(broker: 'KRAKEN', finalTakeProfit:nil)
      @traderFound = @userX
    elsif tvData['broker'] == 'OANDA'
      @userX = User.find_by(oandaToken: apiKey)
      @openTrades = @userX.trades.where(broker: 'OANDA', finalTakeProfit:nil)
      @traderFound = @userX
    elsif tvData['broker'] == 'TRADIER'
    end

    puts "\n-- Current Price: #{tvData['currentPrice'].to_f} --\n"
    # update trade status
    if @openTrades.present? && @openTrades.size > 0
      @openTrades.each do |trade|
        if trade&.broker == 'KRAKEN' 
          requestK = Kraken.orderInfo(trade.uuid, apiKey, secretKey)['result']
          trade.update(status: requestK[trade.uuid]['status'])
          trade.destroy! if trade.status == 'canceled'
        elsif trade&.broker == 'OANDA'
          
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
    if tvData['broker'] == 'KRAKEN'
      afterUpdates =  @userX.trades.where(status: 'closed', broker: 'KRAKEN', finalTakeProfit: nil)
    elsif tvData['broker'] == 'OANDA'
      afterUpdates =  @userX.trades.where(status: 'closed', broker: 'OANDA', finalTakeProfit: nil)
    elsif tvData['broker'] == 'TRADIER'
    end


    # protect closed/filled bot trades
    if afterUpdates.present? && afterUpdates.size > 0
      afterUpdates.each do |tradeX|
        puts "\n-- Starting For #{tradeX.uuid} --\n"
        if tradeX&.broker == 'KRAKEN'
          @requestOriginalE = Kraken.orderInfo(tradeX.uuid, apiKey, secretKey)

          if @requestOriginalE['result'].present?
            originalPrice = @requestOriginalE['result'][tradeX.uuid]['price'].to_f
            originalVolume = @requestOriginalE['result'][tradeX.uuid]['vol'].to_f
          else
            tradeX.destroy!
            next
          end
        elsif tradeX&.broker == 'OANDA'
          requestExecution = Oanda.oandaOrder(apiKey, secretKey, tradeX.uuid)
          @requestOriginalE = Oanda.oandaTrade(apiKey, secretKey, requestExecution['order']['fillingTransactionID'])
          
          originalPrice = @requestOriginalE['trade']['price'].present? ? @requestOriginalE['trade']['price'].to_f : 0
          originalVolume = @requestOriginalE['trade']['initialUnits'].to_f
        elsif tradeX&.broker == 'TRADIER'
        end

        profitTrigger = originalPrice * (0.01 * @traderFound&.profitTrigger)
        volumeTallyForTradex = 0
        openProfitCount = 0

        if tradeX&.broker == 'KRAKEN'
          profitTriggerPassed = (originalPrice + profitTrigger).round(1).to_f
        elsif tradeX&.broker == 'OANDA'
          profitTriggerPassed = (originalPrice + profitTrigger).round(5).to_f
        elsif tradeX&.broker == 'TRADIER'
        end

        if tradeX&.broker == 'OANDA'
          oandaOrderParams = {
            'trailingStopLoss' => {
              'distance' => (tvData['type'] == 'sellStop' ? (profitTriggerPassed + ((0.01 * tvData['trail'].to_f) * profitTriggerPassed) + tvData['currentPrice'].to_f) : ( tvData['currentPrice'].to_f - profitTriggerPassed + ((0.01 * tvData['trail'].to_f) * profitTriggerPassed))).round(3) ,
            }
          }
        end

        if tvData['direction'] == 'sell'
          puts "Profit Trigger Price: #{(profitTriggerPassed + ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)).round(5)}"
          
          if tvData['currentPrice'].to_f > profitTriggerPassed
            if tradeX.take_profits.size == 0
              if tvData['currentPrice'].to_f > profitTriggerPassed + ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)
                
                if tvData['broker'] == 'KRAKEN'
                  @protectTrade = Kraken.newTrail(tvData, @requestOriginalE['result'][tradeX.uuid], apiKey, secretKey, tradeX)
                  if !@protectTrade.empty? && @protectTrade['result']['txid'].present?
                    puts 	"\n-- Taking Profit #{@protectTrade['result']['txid'][0]} --\n"
                  end
                elsif tvData['broker'] == 'OANDA'
                
                  # @protectTrade = Oanda.oandaTrail(tvData, @requestOriginalE, apiKey, secretKey, tradeX)
                  if @requestOriginalE['trade']['currentUnits'].to_f > 0 
                    @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)
                    
                    if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                      puts 	"\n-- Taking Profit #{@protectTrade['trailingStopLossOrderTransaction']['id']} --\n"
                    end
                  end

                elsif tvData['broker'] == 'TRADIER'
                end
              end
            else

              tradeX.take_profits.each do |profitTrade|
                if tvData['broker'] == 'KRAKEN'
                  requestProfitTradex = Kraken.orderInfo(profitTrade.uuid, apiKey, secretKey)
                  profitTrade.update(status: requestProfitTradex['result'][profitTrade.uuid]['status'])
                  volumeForProfit = requestProfitTradex['result'][profitTrade.uuid]['vol'].to_f
                  priceToBeat = requestProfitTradex['result'][profitTrade.uuid]['descr']['price2'].to_f
                elsif tvData['broker'] == 'OANDA'
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

                  if (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) > priceToBeat + ((0.01 * tvData['trail'].to_f) * priceToBeat.round(1).to_f)
                    if tvData['broker'] == 'KRAKEN'
                      krakenOrderParams = {
                        'txid' => profitTrade.uuid
                      }
                      routeToKraken = '/0/private/CancelOrder'

                      cancel = Kraken.request(routeToKraken, krakenOrderParams, apiKey, secretKey)
                      profitTrade.destroy!
                      puts "\n-- Old Take Profit Canceled --\n"

                      @protectTrade = Kraken.newTrail(tvData, @requestOriginalE['result'][tradeX.uuid], apiKey, secretKey, tradeX)
                      
                      if !@protectTrade.empty? && @protectTrade['result']['txid'].present?
                        puts "\n-- Repainting Take Profit #{@protectTrade['result']['txid'][0]} --\n"
                      end
                    elsif tvData['broker'] == 'OANDA'
                      if @requestOriginalE['trade']['currentUnits'].to_f > 0 
                        cancel = Oanda.oandaCancel(apiKey, secretKey, profitTrade.uuid)
                        puts "\n-- Old Take Profit Canceled --\n"
                        # @protectTrade = Oanda.oandaTrail(tvData, @requestOriginalE, apiKey, secretKey, tradeX)
                        @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)
                        
                        if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                          puts  "\n-- Repainting Take Profit #{@protectTrade['trailingStopLossOrderTransaction']['id']} --\n"
                        end
                        profitTrade.destroy!
                        return
                      end

                    elsif tvData['broker'] == 'TRADIER'
                    end
                  end
                elsif profitTrade.status == 'closed' # or other status from oanda/alpaca
                  volumeTallyForTradex += volumeForProfit
                elsif profitTrade.status == 'canceled' # or other status from oanda/alpaca
                  puts "\n-- Removing Canceled Order #{profitTrade.uuid} --\n"
                  profitTrade.destroy!
                  return
                end
              end

              if volumeTallyForTradex < originalVolume
                if openProfitCount == 0
                  if tvData['broker'] == 'KRAKEN'
                    @protectTrade = Kraken.newTrail(tvData, @requestOriginalE['result'][tradeX.uuid], apiKey, secretKey, tradeX)
                    if !@protectTrade.empty? && @protectTrade['result']['txid'].present?
                      puts "\n-- Additional Take Profit #{@protectTrade['result']['txid'][0]} --\n"
                    end
                  elsif tvData['broker'] == 'OANDA'
                    # @protectTrade = Oanda.oandaTrail(tvData, @requestOriginalE, apiKey, secretKey, tradeX)
                    if @requestOriginalE['trade']['currentUnits'].to_f > 0 
                      @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)
                      
                      if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                        puts  "\n-- Additional Take Profit #{@protectTrade['trailingStopLossOrderTransaction']['id']} --\n"
                      end
                    end

                  elsif tvData['broker'] == 'TRADIER'
                  end
                else
                  puts "\n-- Waiting To Close Open Take Profit --\n"
                end
              else
                if tvData['broker'] == 'KRAKEN'
                  checkFill = Kraken.orderInfo(tradeX.take_profits.last.uuid, apiKey, secretKey)
                  tradeX.take_profits.last.update(status: checkFill['result'][tradeX.take_profits.last.uuid]['status'])
                  if checkFill['result'][tradeX.take_profits.last.uuid]['status'] == 'closed'
                    tradeX.update(finalTakeProfit: tradeX.take_profits.last.uuid)
                    puts "\n-- Position Closed #{tradeX.uuid} --\n"
                    puts "\n-- Last Profit Taken #{tradeX.take_profits.last.uuid} --\n"
                  elsif checkFill['result'][tradeX.take_profits.last.uuid]['status'] == 'open'
                    tradeX.update(finalTakeProfit: nil)
                    puts "\n-- Waiting To Close Last Position --\n"
                  end
                elsif tvData['broker'] == 'OANDA'
                  checkFill = Oanda.oandaOrder(apiKey, secretKey, trade.uuid)
                  if checkFill['order']['state'] == 'PENDING'
                    tradeX.update(finalTakeProfit: nil)
                  elsif checkFill['order']['state'] == 'FILLED'
                    tradeX.take_profits.last.update(status: 'closed')
                  end
                elsif tvData['broker'] == 'TRADIER'
                end
              end

            end
          end
        elsif tvData['direction'] == 'buy'
          puts "Profit Trigger Price: #{(profitTriggerPassed - ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)).round(5)}"

          if tvData['currentPrice'].to_f < profitTriggerPassed
            if tradeX.take_profits.empty?
              if tvData['currentPrice'].to_f < profitTriggerPassed - ((0.01 * tvData['trail'].to_f) * profitTriggerPassed)
                
                if tvData['broker'] == 'KRAKEN'
                  @protectTrade = Kraken.newTrail(tvData, @requestOriginalE['result'][tradeX.uuid], apiKey, secretKey, tradeX)
                  if !@protectTrade.empty? && @protectTrade['result']['txid'].present?
                    puts  "\n-- Taking Profit #{@protectTrade['result']['txid'][0]} --\n"
                  end
                elsif tvData['broker'] == 'OANDA'
                  # @protectTrade = Oanda.oandaTrail(tvData, requestExecution, apiKey, secretKey, tradeX)
                  if @requestOriginalE['trade']['currentUnits'].to_f > 0 
                    @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)
                    
                    if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                      puts  "\n-- Taking Profit #{@protectTrade['trailingStopLossOrderTransaction']['id']} --\n"
                    end
                  end

                elsif tvData['broker'] == 'TRADIER'
                end
              end
            else

              tradeX.take_profits.each do |profitTrade|
                if tvData['broker'] == 'KRAKEN'
                  requestProfitTradex = Kraken.orderInfo(profitTrade.uuid, apiKey, secretKey)
                  profitTrade.update(status: requestProfitTradex['result'][profitTrade.uuid]['status'])
                  volumeForProfit = requestProfitTradex['result'][profitTrade.uuid]['vol'].to_f
                  priceToBeat = requestProfitTradex['result'][profitTrade.uuid]['descr']['price2'].to_f
                elsif tvData['broker'] == 'OANDA'
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

                  if (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) < priceToBeat - ((0.01 * tvData['trail'].to_f) * priceToBeat.round(1).to_f)
                    if tvData['broker'] == 'KRAKEN'
                      krakenOrderParams = {
                        'txid' => profitTrade.uuid
                      }
                      routeToKraken = '/0/private/CancelOrder'

                      cancel = Kraken.request(routeToKraken, krakenOrderParams, apiKey, secretKey)
                      profitTrade.destroy!
                      puts "\n-- Old Take Profit Canceled --\n"

                      @protectTrade = Kraken.newTrail(tvData, @requestOriginalE['result'][tradeX.uuid], apiKey, secretKey, tradeX)
                      
                      if !@protectTrade.empty? && @protectTrade['result']['txid'].present?
                        puts "\n-- Repainting Take Profit #{@protectTrade['result']['txid'][0]} --\n"
                      end
                    elsif tvData['broker'] == 'OANDA'
                      if @requestOriginalE['trade']['currentUnits'].to_f > 0 
                        cancel = Oanda.oandaCancel(apiKey, secretKey, profitTrade.uuid)
                        profitTrade.destroy!
                        puts "\n-- Old Take Profit Canceled --\n"
                        # @protectTrade = Oanda.oandaTrail(tvData, requestExecution, apiKey, secretKey, tradeX)
                        @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)
                        
                        if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                          puts  "\n-- Repainting Take Profit #{@protectTrade['trailingStopLossOrderTransaction']['id']} --\n"
                        end
                      end
                    elsif tvData['broker'] == 'TRADIER'
                    end
                  end
                elsif profitTrade.status == 'closed' # or other status from oanda/alpaca
                  volumeTallyForTradex += volumeForProfit
                elsif profitTrade.status == 'canceled' # or other status from oanda/alpaca
                  puts "\n-- Removing Canceled Order #{profitTrade.uuid} --\n"
                  profitTrade.destroy!
                  next
                end
              end

              if volumeTallyForTradex > originalVolume
                if openProfitCount == 0
                  if tvData['broker'] == 'KRAKEN'
                    @protectTrade = Kraken.newTrail(tvData, @requestOriginalE['result'][tradeX.uuid], apiKey, secretKey, tradeX)
                    if !@protectTrade.empty? && @protectTrade['result']['txid'].present?
                      puts "\n-- Additional Take Profit #{@protectTrade['result']['txid'][0]} --\n"
                    end
                  elsif tvData['broker'] == 'OANDA'
                    # @protectTrade = Oanda.oandaTrail(tvData, requestExecution, apiKey, secretKey, tradeX)
                    if @requestOriginalE['trade']['currentUnits'].to_f > 0 
                      @protectTrade = Oanda.oandaUpdateTrade(tvData, apiKey, secretKey, @requestOriginalE['trade']['id'], oandaOrderParams, tradeX)

                      if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                        puts  "\n-- Additional Take Profit #{@protectTrade['trailingStopLossOrderTransaction']['id']} --\n"
                      end
                    end
                  elsif tvData['broker'] == 'TRADIER'
                  end
                else
                  puts "\n-- Waiting To Close Open Take Profit --\n"
                end
              else
                if tvData['broker'] == 'KRAKEN'
                  checkFill = Kraken.orderInfo(tradeX.take_profits.last.uuid, apiKey, secretKey)
                  tradeX.take_profits.last.update(status: checkFill['result'][tradeX.take_profits.last.uuid]['status'])
                  if checkFill['result'][tradeX.take_profits.last.uuid]['status'] == 'closed'
                    tradeX.update(finalTakeProfit: tradeX.take_profits.last.uuid)
                    puts "\n-- Position Closed #{tradeX.uuid} --\n"
                    puts "\n-- Last Profit Taken #{tradeX.take_profits.last.uuid} --\n"
                  elsif checkFill['result'][tradeX.take_profits.last.uuid]['status'] == 'open'
                    tradeX.update(finalTakeProfit: nil)
                    puts "\n-- Waiting To Close Last Position --\n"
                  end
                elsif tvData['broker'] == 'OANDA'
                  checkFill = Oanda.oandaOrder(apiKey, secretKey, trade.uuid)
                  if checkFill['order']['state'] == 'PENDING'
                    tradeX.update(finalTakeProfit: nil)
                  elsif checkFill['order']['state'] == 'FILLED'
                    tradeX.take_profits.last.update(status: 'closed')
                  end
                elsif tvData['broker'] == 'TRADIER'
                end
              end

            end
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

    if tvData['broker'] == 'KRAKEN'
      @traderFound = User.find_by(krakenLiveAPI: apiKey)
    elsif tvData['broker'] == 'OANDA'
      @traderFound = User.find_by(oandaToken: apiKey)
    elsif tvData['broker'] == 'TRADIER'
      @traderFound = User.find_by(tradierToken: apiKey)
    end



    # variables
    orderforMulti = 0

    if tvData['broker'] == 'KRAKEN'
      @unitsToTrade = Kraken.krakenRisk(tvData, apiKey, secretKey)

      if @unitsToTrade > 0
        @pairCall = Kraken.publicPair(tvData, apiKey, secretKey)

        @resultKey = @pairCall['result'].keys.first
        @baseTicker = "Z#{ISO3166::Country[@traderFound&.amazonCountry&.downcase].currency_code}"
        @tickerForAllocation = @pairCall['result'][@resultKey]['altname']
        @base = @pairCall['result'][@resultKey]['base']

        @amountToRisk = Kraken.krakenRisk(tvData, apiKey, secretKey)
        @currentOpenAllocation = Kraken.pendingTrades(apiKey, secretKey)
        openOrdersPending = @currentOpenAllocation.map { |d| d[1] }.reject { |d| d['descr']['type'] != tvData['direction'] }.reject { |d| d['descr']['pair'] != @tickerForAllocation }.map { |d| d['vol'].to_f * d['descr']['price'].to_f }.sum
        amountToRisk = @amountToRisk * tvData['currentPrice'].to_f

        @balanceCall = Kraken.krakenBalance(apiKey, secretKey)['result']

        @accountTotal = @balanceCall[ @baseTicker].to_f + (tvData['currentPrice'].to_f * @balanceCall[@base].to_f)

        orderforMulti += @traderFound&.allowMarketOrder ? 1 : 0
        tvData['entries'].reject(&:blank?).size > 0 ? orderforMulti += tvData['entries'].reject(&:blank?).size : orderforMulti += 0
      end
    elsif tvData['broker'] == 'OANDA'
      @amountToRisk = Oanda.oandaRisk(tvData, apiKey, secretKey)

      oandaAccount = Oanda.oandaAccount(apiKey, secretKey)
      cleanTickers = oandaAccount['account']['positions'].map { |d| d['instrument'].tr!('_', '') }

      foundTickerPosition = oandaAccount['account']['positions'].reject { |d| d['instrument'] != tvData['ticker'] }.first
      foundTickerOrders = oandaAccount['account']['orders'].reject { |d| d['instrument'] != "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}" }

      marginUsed = foundTickerPosition.present? && foundTickerPosition['marginUsed'].present? ? foundTickerPosition['marginUsed'].to_f : 0

      openOrders = (oandaAccount['account']['marginRate'].to_f * foundTickerOrders.map { |d| d['units'].to_i }.sum)
      openOrdersPending = openOrders
      accountBalance = ((marginUsed + openOrders) + oandaAccount['account']['marginAvailable'].to_f)

      orderforMulti += @traderFound&.allowMarketOrder ? 1 : 0
      tvData['entries'].reject(&:blank?).size > 0 ? orderforMulti += tvData['entries'].reject(&:blank?).size : orderforMulti += 0
    elsif tvData['broker'] == 'TRADIER'
    end

    
    if tvData['broker'] == 'KRAKEN'
     filledOrders = (@balanceCall[@base].to_f * tvData['currentPrice'].to_f)
     @currentRisk = calculateRiskAfterTrade(filledOrders,openOrdersPending, (amountToRisk * orderforMulti),  @accountTotal)
    elsif tvData['broker'] == 'OANDA'
     @currentRisk = calculateRiskAfterTrade(marginUsed,openOrdersPending, (@amountToRisk * orderforMulti),  accountBalance)
    elsif tvData['broker'] == 'TRADIER'
    end

    # ticker specific

    if tvData['ticker'] == 'BTCUSD'
      @unitsFiltered = (@unitsToTrade > 0.0001 ? @unitsToTrade : 0.0001)
    end
    
    if @currentRisk.round(2) < @traderFound&.maxRisk && @currentRisk.round(2) >= 0
     priceForProfit = (tvData['direction'] == 'sell' ? tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * @traderFound&.profitTrigger)) : tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * @traderFound&.profitTrigger))).round(5)

      # market order
      if @traderFound&.allowMarketOrder == 'true'
        # set order params

        if tvData['broker'] == 'KRAKEN'
          krakenOrderParams = {
            'pair' => tvData['ticker'],
            'type' => tvData['direction'],
            'ordertype' => 'market',
            'volume' => @unitsFiltered.to_s
          }
        elsif tvData['broker'] == 'OANDA'
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

          if tvData['broker'] == 'KRAKEN'
            @requestK = Kraken.request('/0/private/AddOrder', krakenOrderParams, apiKey, secretKey)
            if @requestK['result']
              pullRequestK = Kraken.orderInfo(@requestK['result']['txid'][0], @traderFound.krakenLiveAPI, @traderFound.krakenLiveSecret)
            else
              return
            end
          elsif tvData['broker'] == 'OANDA'
            @requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
          elsif tvData['broker'] == 'TRADIER'
          end
        end

        # put order
        if tvData['direction'] == 'sell'

          if tvData['broker'] == 'KRAKEN'
            @requestK = Kraken.request('/0/private/AddOrder', krakenOrderParams, apiKey, secretKey)
            if @requestK['result']
              @pullRequestK = Kraken.orderInfo(@requestK['result']['txid'][0], @traderFound.krakenLiveAPI, @traderFound.krakenLiveSecret)
            else
              return
            end
          elsif tvData['broker'] == 'OANDA'
            @requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
          elsif tvData['broker'] == 'TRADIER'
          end
        end

        # update database with ID from @requestK

        if tvData['broker'] == 'KRAKEN'
          if @requestK.present? && @requestK['orderCreateTransaction'].present?

            if @requestK['result']['txid'].present?
              User.find_by(krakenLiveAPI: apiKey).trades.create(traderID: tvData['traderID'], uuid: @requestK['result']['txid'][0], broker: tvData['broker'], direction: tvData['direction'], status: 'open', cost: @pullRequestK['result'][@requestK['result']['txid'][0]]['cost'].to_f)
              puts "\n-- #{tvData['broker']} Entry Submitted --\n"
              puts "\n-- Current Risk #{@currentRisk.round(2)} --\n"
            end
          else
            if @requestK['error'][0].present? && @requestK['error'][0].include?('Insufficient')
              puts "\n-- MORE CASH FOR ENTRIES --\n"
              puts "\n-- Current Risk #{ @currentRisk.round(2)} --\n"
            end
          end
        elsif tvData['broker'] == 'OANDA'

          if @requestK.present? && @requestK['orderCreateTransaction'].present?
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
          if tvData['broker'] == 'KRAKEN'
            priceToSet = (tvData['direction'] == 'sell' ? tvData['highPrice'].to_f + (tvData['highPrice'].to_f * (0.01 * entryPercentage.to_f)) : tvData['lowPrice'].to_f - (tvData['lowPrice'].to_f * (0.01 * entryPercentage.to_f))).round(1)
          elsif tvData['broker'] == 'OANDA'
            priceToSet = (tvData['direction'] == 'sell' ? tvData['highPrice'].to_f + (tvData['highPrice'].to_f * (0.01 * entryPercentage.to_f)) : tvData['lowPrice'].to_f - (tvData['lowPrice'].to_f * (0.01 * entryPercentage.to_f))).round(5)
          elsif tvData['broker'] == 'TRADIER'
          end
          # set order params

          if tvData['broker'] == 'KRAKEN'
            krakenParams0 = {
              'pair' => tvData['ticker'],
              'type' => tvData['direction'],
              'ordertype' => 'limit',
              'price' => priceToSet.to_s,
              'volume' => @unitsFiltered.to_s
            }
          elsif tvData['broker'] == 'OANDA'
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

            if tvData['broker'] == 'KRAKEN'
              requestK = Kraken.request('/0/private/AddOrder', krakenParams0, apiKey, secretKey)
              if requestK['result']
                pullRequestK = Kraken.orderInfo(requestK['result']['txid'][0], @traderFound.krakenLiveAPI, @traderFound.krakenLiveSecret)
              else
                return
              end
            elsif tvData['broker'] == 'OANDA'
              requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
            elsif tvData['broker'] == 'TRADIER'
            end
          end
          # put order
          if tvData['direction'] == 'sell'

            if tvData['broker'] == 'KRAKEN'
              requestK = Kraken.request('/0/private/AddOrder', krakenParams0, apiKey, secretKey)
              if requestK['result']
                pullRequestK = Kraken.orderInfo(requestK['result']['txid'][0], @traderFound.krakenLiveAPI, @traderFound.krakenLiveSecret)
              else
                return
              end
            elsif tvData['broker'] == 'OANDA'
              requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
            elsif tvData['broker'] == 'TRADIER'
            end
          end

          # update database with ID from requestK

          if tvData['broker'] == 'KRAKEN'
            if requestK.present? && requestK['result'].present?
              if requestK['result']['txid'].present?
                

                User.find_by(krakenLiveAPI: apiKey).trades.create(traderID: tvData['traderID'], uuid: requestK['result']['txid'][0], broker: tvData['broker'], direction: tvData['direction'], status: 'open', cost: pullRequestK['result'][requestK['result']['txid'][0]]['cost'].to_f)
                puts "\n-- #{tvData['broker']} Entry Submitted --\n"
                puts "\n-- Current Risk #{@currentRisk.round(2)} --\n"
              end
            else
              if requestK['error'][0].present? && requestK['error'][0].include?('Insufficient')
                puts "\n-- MORE CASH FOR ENTRIES --\n"
                puts "\n-- Current Risk #{ @currentRisk.round(2)} --\n"
              end
            end
          elsif tvData['broker'] == 'OANDA'
            if requestK.present? && requestK['orderCreateTransaction'].present?
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
