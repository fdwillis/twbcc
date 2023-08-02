class TradingviewController < ApplicationController
  require 'sidekiq/api'
  protect_from_forgery with: :null_session

  def targets
    # pull all closed trades -> build result to display
    # pull all open trades -> build result to display
    @allTrades = Trade.all.where('created_at > ?', 30.days.ago)
    @entriesTradesall = @allTrades.where(status: 'closed')
    @currentTradesall = @entriesTradesall.where(finalTakeProfit: nil)
    
    usersForMap = @allTrades.map(&:user).uniq

    cryptoAssets = 0
    forexAssets = 0
    stocksAssets = 0
    optionsAssets = 0

    @currentTrades24 = @currentTradesall.where('created_at > ?', 7.days.ago)
    @entriesTrades24 = @entriesTradesall.where('created_at > ?', 7.days.ago)

    @currentTrades = @currentTradesall
    @entriesTrades = @entriesTradesall

    @profitTotal = 0
    @partialClose = 0
    @partialClose24 = 0
    @partialCloseall = 0

    @assetsUM = 0

    usersForMap.each do |user|
      # assets under management (tally together crypto, forex, stocks, options)
      if user&.oandaToken.present? && user&.oandaList.present?
        oandaAccounts = user&.oandaList.split(',')
        oandaAccounts.each do |accountID|
          oandaX = Oanda.oandaRequest(user&.oandaToken, accountID)
          balanceX = Oanda.oandaBalance(user&.oandaToken, accountID)
          @assetsUM += balanceX
        end
      end

    end

    @partialClose += @entriesTrades.map(&:take_profits).count

    @partialClose24 += @entriesTrades24.map(&:take_profits).count

    @partialCloseall += @entriesTradesall.map(&:take_profits).count
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
    if Time.now.strftime("%H").to_i != 15 && Time.now.strftime("%H").to_i != 16 && Time.now.strftime("%H").to_i != 17 && Time.now.strftime("%H").to_i != 18
      params['sequence'].to_enum.to_a.each do |sequence|
        traderID = params['traderID']
        traderFound = User.find_by(uuid: traderID)
        traderFound&.checkMembership
        validPlansToParse = []

        if sequence['traderOnly'] == 'false'
          puts "\n-- Starting To Copy Trades For Followers --\n"
          # pull those with done for you plan

          memberTypes = User::USERmembership + User::CAPTAINmembership + User::TRADERmembership

          memberTypes.each do |memberType|
            planX = Stripe::Subscription.list({ limit: 100, price: memberType })['data'].reject { |d| d['status'] != 'active' }
            validPlansToParse << planX
          end

          validPlansToParse.reject(&:blank?).flatten.each do |planXinfo|
            traderFoundForCopy = User.find_by(stripeCustomerID: planXinfo['customer'])
            traderFoundForCopy&.checkMembership

            if  traderFoundForCopy&.trader? && !ENV["adminUUID"].include?(traderFoundForCopy&.uuid)
                  
              puts "\n-- Started For #{traderFoundForCopy.uuid} #{sequence.to_enum.to_h['type']} #{sequence.to_enum.to_h['direction']} --\n"
              listToTrade = traderFoundForCopy&.authorizedList.present? ? traderFoundForCopy&.authorizedList&.delete(' ').split(",") : []
              assetList = listToTrade.present? ? listToTrade : []
              if assetList.size > 0
                assetList.each do |assetX|
                  if assetX.upcase == sequence['ticker']
                    # execute trade
                    case true
                    when sequence['type'].include?('Stop')
                      puts "\n-- Starting Stop --\n"
                      case true
                      when sequence['broker'] == 'KRAKEN'
                        BackgroundJob.perform_async('stop', sequence.to_enum.to_h, traderFoundForCopy.krakenLiveAPI, traderFoundForCopy.krakenLiveSecret)
                      when sequence['broker'] == 'OANDA'
                        traderFoundForCopy&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                          BackgroundJob.perform_async('stop', sequence.to_enum.to_h, traderFoundForCopy.oandaToken, accountID)
                        end
                      when sequence['broker'] == 'TRADIER'
                        BackgroundJob.perform_async('stop', sequence.to_enum.to_h, traderFoundForCopy&.tradierToken, nil)
                      end
                    when sequence['type'] == 'entry'
                      puts "\n-- Starting Entry #{sequence.to_enum.to_h['type']} #{sequence.to_enum.to_h['direction']} --\n"
                      case true
                      when sequence['broker'] == 'KRAKEN'
                        BackgroundJob.perform_async('entry', sequence.to_enum.to_h, traderFoundForCopy.krakenLiveAPI, traderFoundForCopy.krakenLiveSecret)
                      when sequence['broker'] == 'OANDA'
                        traderFoundForCopy&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                          BackgroundJob.perform_async('entry', sequence.to_enum.to_h, traderFoundForCopy.oandaToken, accountID)
                        end
                      when sequence['broker'] == 'TRADIER'
                        BackgroundJob.perform_async('entry', sequence.to_enum.to_h, traderFoundForCopy&.tradierToken, nil)
                      end
                    when sequence['type'].include?('profit')
                    when sequence['type'] == 'kill'
                      puts "\n-- Starting Kill --\n"
                      case true
                      when sequence['broker'] == 'KRAKEN'
                        BackgroundJob.perform_async('kill', sequence.to_enum.to_h, traderFoundForCopy.krakenLiveAPI, traderFoundForCopy.krakenLiveSecret)
                      when sequence['broker'] == 'OANDA'
                        traderFoundForCopy&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                          BackgroundJob.perform_async('kill', sequence.to_enum.to_h, traderFoundForCopy.oandaToken, accountID)
                        end
                      when sequence['broker'] == 'TRADIER'
                        BackgroundJob.perform_async('kill', sequence.to_enum.to_h, traderFoundForCopy&.tradierToken, nil)
                      end
                    end
                  elsif (DateTime.now.strftime('%a') != 'Sun' && DateTime.now.strftime('%a') != 'Sat') && traderFoundForCopy.trial?
                    if (current_user&.authorizedList == 'crypto')
                      tickerForTrial = "BTC#{ISO3166::Country[traderFoundForCopy&.amazonCountry.downcase].currency_code}"
                    else (current_user&.authorizedList == 'forex')
                      tickerForTrial = "EUR#{ISO3166::Country[traderFoundForCopy&.amazonCountry.downcase].currency_code}"
                    end

                    if sequence['ticker'] == tickerForTrial
                      case true
                      when sequence['type'].include?('Stop')
                        puts "\n-- Starting Stop --\n"
                        case true
                        when sequence['broker'] == 'KRAKEN'
                          BackgroundJob.perform_async('stop', sequence.to_enum.to_h, traderFoundForCopy&.krakenLiveAPI, traderFoundForCopy&.krakenLiveSecret)
                        when sequence['broker'] == 'OANDA'
                          traderFoundForCopy&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                            BackgroundJob.perform_async('stop', sequence.to_enum.to_h, traderFoundForCopy&.oandaToken, accountID)
                          end
                        when sequence['broker'] == 'TRADIER'
                          BackgroundJob.perform_async('stop', sequence.to_enum.to_h, traderFoundForCopy&.tradierToken, nil)
                        end
                      when sequence['type'] == 'entry'
                        puts "\n-- Starting Entry #{sequence.to_enum.to_h['type']} #{sequence.to_enum.to_h['direction']} --\n"
                        case true
                        when sequence['broker'] == 'KRAKEN'
                          BackgroundJob.perform_async('entry', sequence.to_enum.to_h, traderFoundForCopy&.krakenLiveAPI, traderFoundForCopy&.krakenLiveSecret)
                        when sequence['broker'] == 'OANDA'
                          traderFoundForCopy&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                            BackgroundJob.perform_async('entry', sequence.to_enum.to_h, traderFoundForCopy&.oandaToken, accountID)
                          end
                        when sequence['broker'] == 'TRADIER'
                          BackgroundJob.perform_async('entry', sequence.to_enum.to_h, traderFoundForCopy&.tradierToken, nil)
                        end
                      when sequence['type'].include?('profit')
                      when sequence['type'] == 'kill'
                        puts "\n-- Starting Kill --\n"
                        case true
                        when sequence['broker'] == 'KRAKEN'
                          BackgroundJob.perform_async('kill', sequence.to_enum.to_h, traderFoundForCopy&.krakenLiveAPI, traderFoundForCopy&.krakenLiveSecret)
                        when sequence['broker'] == 'OANDA'
                          traderFoundForCopy&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                            BackgroundJob.perform_async('kill', sequence.to_enum.to_h, traderFoundForCopy&.oandaToken, accountID)
                          end
                        when sequence['broker'] == 'TRADIER'
                          BackgroundJob.perform_async('kill', sequence.to_enum.to_h, traderFoundForCopy&.tradierToken, nil)
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
      

          
        if sequence['forTrader'] == 'true'
  
          case true
          when sequence['type'].include?('Stop')
            puts "\n-- Starting Stop --\n"
            case true
            when sequence['broker'] == 'KRAKEN'
              BackgroundJob.perform_async('stop', sequence.to_enum.to_h, traderFound&.krakenLiveAPI, traderFound&.krakenLiveSecret)
            when sequence['broker'] == 'OANDA'
              traderFound&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                BackgroundJob.perform_async('stop', sequence.to_enum.to_h, traderFound&.oandaToken, accountID)
              end
            when sequence['broker'] == 'TRADIER'
              BackgroundJob.perform_async('stop', sequence.to_enum.to_h, traderFound&.tradierToken, nil)
            end
          when sequence['type'] == 'entry'
            case true
            when sequence['broker'] == 'KRAKEN'
              BackgroundJob.perform_async('entry', sequence.to_enum.to_h, traderFound&.krakenLiveAPI, traderFound&.krakenLiveSecret)
            when sequence['broker'] == 'OANDA'
              traderFound&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                BackgroundJob.perform_async('entry', sequence.to_enum.to_h, traderFound&.oandaToken, accountID)
              end
            when sequence['broker'] == 'TRADIER'
              BackgroundJob.perform_async('entry', sequence.to_enum.to_h, traderFound&.tradierToken, nil)
            end
          when sequence['type'].include?('profit')
          when sequence['type'] == 'kill'
            puts "\n-- Starting Kill --\n"
            case true
            when sequence['broker'] == 'OANDA'
              traderFound&.oandaList.split(',')&.reject(&:blank?).each do |accountID|
                BackgroundJob.perform_async('kill', sequence.to_enum.to_h, traderFound&.oandaToken, accountID)
              end
            when sequence['broker'] == 'TRADIER'
              BackgroundJob.perform_async('kill', sequence.to_enum.to_h, traderFound&.tradierToken, nil)
            end
          end
          puts "\n-- Finished Admin Trades --\n"
        end

          

      end
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
    params.require(:authorizedList).permit(:authorizedList, :username)
  end

  def tradingviewKeysparams
    params.permit(:sequence.to_enum.to_h, :killType, :traderID, :adminOnly, :tradeForAdmin, :ticker, :type, :direction, :timeframe, :currentPrice, :highPrice, :tradingview, :traderID, :lowPrice, :broker, :trail, entries: [])
  end

  def profitTriggersparams
    params.require(:profitTriggers).permit(:perEntry, :reduceBy, :profitTrigger, :maxRisk, :allowMarketOrder)
  end
end
