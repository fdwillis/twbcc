class TradingviewController < ApplicationController
  require 'sidekiq/api'
  protect_from_forgery with: :null_session

  def targets
    # pull all closed trades -> build result to display
    # pull all open trades -> build result to display
    @allTrades = Trade.all
    @currentTradesall = @allTrades.where(finalTakeProfit: nil, status: 'closed')
    @entriesTradesall = @allTrades.where(status: 'closed')

    cryptoAssets = 0
    forexAssets = 0
    stocksAssets = 0
    optionsAssets = 0

    @currentTrades24 = @currentTradesall.where('created_at > ?', 7.days.ago)
    @entriesTrades24 = @entriesTradesall.where('created_at > ?', 7.days.ago)

    @currentTrades = @currentTradesall.where('created_at > ?', 30.days.ago)
    @entriesTrades = @entriesTradesall.where('created_at > ?', 30.days.ago)

    @profitTotal = 0
    @partialClose = 0
    @partialClose24 = 0
    @partialCloseall = 0

    @assetsUM = 0
    @initalBalance = ApplicationRecord::INITALBALANCE.map { |d| d['initialDepopsit'] }.sum

    @entriesTrades.each do |entry|
      @partialClose += 1 if entry.take_profits.size > 0
    end

    @entriesTrades24.each do |entry|
      @partialClose24 += 1 if entry.take_profits.size > 0
    end

    @entriesTradesall.each do |entry|
      @partialCloseall += 1 if entry.take_profits.size > 0
    end

    User.all.each do |user|
      # assets under management (tally together crypto, forex, stocks, options)
      if user&.oandaToken.present? && user&.oandaList.present?
        oandaAccounts = user&.oandaList.split(',')
        oandaAccounts.each do |accountID|
          oandaX = Oanda.oandaRequest(user&.oandaToken, accountID)
          balanceX = Oanda.oandaBalance(user&.oandaToken, accountID)
          @assetsUM += balanceX
        end
      end

      next unless user&.krakenLiveAPI.present? && user&.krakenLiveSecret.present?

      balanceX = Kraken.krakenBalance(user&.krakenLiveAPI, user&.krakenLiveSecret)
      krakenResult = balanceX['result'].reject { |_d, f| f.to_f == 0 }
      baseCurrency = krakenResult.reject { |d, _f| !d.include?('Z') }.keys[0]
      @assetsUM += krakenResult[baseCurrency].to_f

      krakenResult.except(baseCurrency).each do |resultX|
        baseTicker = resultX[0]
        assetInfo = Kraken.assetInfo({ 'ticker' => baseTicker }, user&.krakenLiveAPI, user&.krakenLiveSecret)
        units = balanceX['result'][baseTicker].to_f
        altName = assetInfo['result'][baseTicker]['altname']
        tickerInfo = Kraken.tickerInfo({ 'ticker' => "#{altName}#{baseCurrency.delete('Z')}" }, user&.krakenLiveAPI, user&.krakenLiveSecret)

        ask = tickerInfo['result']["#{baseTicker}#{baseCurrency}"]['a'][0].to_f
        bid = tickerInfo['result']["#{baseTicker}#{baseCurrency}"]['b'][0].to_f

        averagePrice = (ask + bid) / 2

        risked = averagePrice * units
        @assetsUM += risked
      end
    end
  end

  def manage_trading_keys
    if params['editKeys'] && autoTradingKeysparams.present?
      current_user.update(autoTradingKeysparams)
      flash[:success] = 'Keys Updated'
      redirect_to request.referrer
      nil
    elsif params['authorizedList'] && authorizedListParams.present?
      current_user.update(authorizedListParams)
      flash[:success] = 'Authorized List Updated'
      redirect_to request.referrer
      nil
    elsif profitTriggersparams.present?
      current_user.update(profitTriggersparams)
      flash[:success] = 'Profit Triggers & Risk Tolerance Updated'
      redirect_to request.referrer
      nil
    else
      flash[:notice] = 'Cannot Be Blank'
      redirect_to request.referrer
      nil
    end
  end

  def signals
    traderID = params['traderID']
    traderFound = User.find_by(uuid: traderID)
    if params['tradingDays'].present? && params['tradingDays'].map { |d| d.downcase }.include?(Date.today.strftime('%a').downcase)
      if traderFound.trader?

        if Oj.load(ENV['adminUUID']).include?(traderFound.uuid)
          if params['tradeForAdmin'] == 'true'
            case true
            when params['type'].include?('Stop')
              case true
              when params['broker'] == 'KRAKEN'
                BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFound&.krakenLiveAPI, traderFound&.krakenLiveSecret)
              when params['broker'] == 'OANDA'
                traderFound&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                  BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFound&.oandaToken, accountID)
                end
              end
            when params['type'] == 'entry'
              case true
              when params['broker'] == 'KRAKEN'
                BackgroundJob.perform_async('entry', tradingviewKeysparams.to_h, traderFound&.krakenLiveAPI, traderFound&.krakenLiveSecret)
              when params['broker'] == 'OANDA'
                traderFound&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                  BackgroundJob.perform_async('entry', tradingviewKeysparams.to_h, traderFound&.oandaToken, accountID)
                end
              end
            when params['type'].include?('profit')
            when params['type'] == 'kill'
              case true
              when params['broker'] == 'KRAKEN'
                BackgroundJob.perform_async('kill', tradingviewKeysparams.to_h, traderFound&.krakenLiveAPI, traderFound&.krakenLiveSecret)
              when params['broker'] == 'OANDA'
                traderFound&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                  BackgroundJob.perform_async('kill', tradingviewKeysparams.to_h, traderFound&.oandaToken, accountID)
                end
              end
            end
            puts "\n-- Finished Admin Trades --\n"
          end

          if params['adminOnly'] == 'false'
            puts "\n-- Starting To Copy Trades --\n"
            # pull those with done for you plan
            monthlyAuto = Stripe::Subscription.list({ limit: 100, price: ENV['autoTradingMonthlyMembership'] })['data'].reject { |d| d['status'] != 'active' }
            annualAuto = Stripe::Subscription.list({ limit: 100, price: ENV['autoTradingAnnualMembership'] })['data'].reject { |d| d['status'] != 'active' }
            trial = Stripe::Subscription.list({ limit: 100, price: ENV['trialTradingDaily'] })['data'].reject { |d| d['status'] != 'active' }
            validPlansToParse = monthlyAuto + annualAuto + trial

            validPlansToParse.each do |planXinfo|
              traderFoundForCopy = User.find_by(stripeCustomerID: planXinfo['customer'])
              listToTrade = traderFoundForCopy&.authorizedList.present? ? traderFoundForCopy&.authorizedList&.delete(' ').split(",") : []

              unless traderFoundForCopy.admin?
                puts "\n-- Started For #{traderFoundForCopy.uuid} --\n"
                assetList = listToTrade.present? ? listToTrade : []
                if assetList.size > 0
                  assetList.each do |assetX|
                    
                    if assetX.upcase == params['ticker']
                      # execute trade
                      case true
                      when params['type'].include?('Stop')
                        case true
                        when params['broker'] == 'KRAKEN'
                          BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFoundForCopy.krakenLiveAPI, traderFoundForCopy.krakenLiveSecret)
                        when params['broker'] == 'OANDA'
                          traderFoundForCopy&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                            BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFoundForCopy.oandaToken, accountID)
                          end
                        end
                      when params['type'] == 'entry'
                        case true
                        when params['broker'] == 'KRAKEN'
                          BackgroundJob.perform_async('entry', tradingviewKeysparams.to_h, traderFoundForCopy.krakenLiveAPI, traderFoundForCopy.krakenLiveSecret)
                        when params['broker'] == 'OANDA'
                          traderFoundForCopy&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                            BackgroundJob.perform_async('entry', tradingviewKeysparams.to_h, traderFoundForCopy.oandaToken, accountID)
                          end
                        end
                      when params['type'].include?('profit')
                      when params['type'] == 'kill'
                        case true
                        when params['broker'] == 'KRAKEN'
                          BackgroundJob.perform_async('kill', tradingviewKeysparams.to_h, traderFoundForCopy.krakenLiveAPI, traderFoundForCopy.krakenLiveSecret)
                        when params['broker'] == 'OANDA'
                          BackgroundJob.perform_async('kill', tradingviewKeysparams.to_h, traderFoundForCopy.oandaToken, nil)
                        end
                      end
                    elsif (DateTime.now.strftime('%a') != 'Sun' && DateTime.now.strftime('%a') != 'Sat') && traderFoundForCopy.trial?
                      if (current_user&.authorizedList == 'crypto')
                        tickerForTrial = "BTC#{ISO3166::Country[traderFoundForCopy&.amazonCountry.downcase].currency_code}"
                      else (current_user&.authorizedList == 'forex')
                        tickerForTrial = "EUR#{ISO3166::Country[traderFoundForCopy&.amazonCountry.downcase].currency_code}"
                      end

                      if tradingviewKeysparams['ticker'] == tickerForTrial
                        case true
                        when params['type'].include?('Stop')
                          case true
                          when params['broker'] == 'KRAKEN'
                            BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFoundForCopy&.krakenLiveAPI, traderFoundForCopy&.krakenLiveSecret)
                          when params['broker'] == 'OANDA'
                            traderFoundForCopy&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                              BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFoundForCopy&.oandaToken, accountID)
                            end
                          end
                        when params['type'] == 'entry'
                          case true
                          when params['broker'] == 'KRAKEN'
                            BackgroundJob.perform_async('entry', tradingviewKeysparams.to_h, traderFoundForCopy&.krakenLiveAPI, traderFoundForCopy&.krakenLiveSecret)
                          when params['broker'] == 'OANDA'
                            traderFoundForCopy&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                              BackgroundJob.perform_async('entry', tradingviewKeysparams.to_h, traderFoundForCopy&.oandaToken, accountID)
                            end
                          end
                        when params['type'].include?('profit')
                        when params['type'] == 'kill'
                          case true
                          when params['broker'] == 'KRAKEN'
                            BackgroundJob.perform_async('kill', tradingviewKeysparams.to_h, traderFoundForCopy&.krakenLiveAPI, traderFoundForCopy&.krakenLiveSecret)
                          when params['broker'] == 'OANDA'
                            BackgroundJob.perform_async('kill', tradingviewKeysparams.to_h, traderFoundForCopy&.oandaToken, nil)
                          end
                        end
                      else
                        puts "\n-- Alerts Needed For #{tickerForTrial} --\n"
                      end
                    end
                  end
                end
              end
              puts "\n-- Finished Copying Trades --\n"
            end

          end

        else
          case true
          when params['type'].include?('Stop')
            case true
            when params['broker'] == 'KRAKEN'
              BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFound&.krakenLiveAPI, traderFound&.krakenLiveSecret)
            when params['broker'] == 'OANDA'
              traderFound&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                BackgroundJob.perform_async('stop', tradingviewKeysparams.to_h, traderFound&.oandaToken, accountID)
              end
            end
          when params['type'] == 'entry'
            case true
            when params['broker'] == 'KRAKEN'
              BackgroundJob.perform_async('entry', tradingviewKeysparams.to_h, traderFound&.krakenLiveAPI, traderFound&.krakenLiveSecret)
            when params['broker'] == 'OANDA'
              traderFound&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                BackgroundJob.perform_async('entry', tradingviewKeysparams.to_h, traderFound&.oandaToken, accountID)
              end
            end
          when params['type'].include?('profit')
          when params['type'] == 'kill'
            case true
            when params['broker'] == 'KRAKEN'
              BackgroundJob.perform_async('kill', tradingviewKeysparams.to_h, traderFound&.krakenLiveAPI, traderFound&.krakenLiveSecret)
            when params['broker'] == 'OANDA'
              traderFound&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                BackgroundJob.perform_async('kill', tradingviewKeysparams.to_h, traderFound&.oandaToken, accountID)
              end
            end
          end
        end

       

        render json: { success: true }
      else
        puts "\n-- No Trader Found --\n"
      end
    else
      puts "\n-- No Trading Today--\n"
    end
  rescue StandardError => e
    puts e
    Sidekiq.redis(&:flushdb)
  end

  private

  def autoTradingKeysparams
    params.require(:editKeys).permit(:krakenLiveAPI, :krakenLiveSecret, :krakenTestAPI, :krakenTestSecret, :oandaToken, :oandaList)
  end

  def authorizedListParams
    params.require(:authorizedList).permit(:authorizedList)
  end

  def tradingviewKeysparams
    params.permit(:adminOnly, :tradeForAdmin, :ticker, :tickerType, :type, :direction, :timeframe, :currentPrice, :highPrice, :tradingview, :traderID, :lowPrice, :broker, :trail, entries: [], tradingDays: [])
  end

  def profitTriggersparams
    params.require(:profitTriggers).permit(:perEntry, :reduceBy, :profitTrigger, :maxRisk, :allowMarketOrder)
  end
end
