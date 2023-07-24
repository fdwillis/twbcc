class Oanda < ApplicationRecord
  def self.oandaRequest(token, accountID)
    @oanda = OandaApiV20.new(access_token: token,practice:true)
  end

  def self.oandaAccount(token, accountID)
    oandaRequest(token, accountID).account(accountID).show
  end

  def self.oandaBalance(token, accountID)
    accountToFind = Oanda.oandaAccount(token, accountID)

    accountBalance = accountToFind['account']['balance'].to_f
  end

  def self.oandaPendingOrders(token, accountID)
    oandaRequest(token, accountID).account(accountID).pending_orders.show
  end

  def self.oandaEntry(token, accountID, orderParams)
    oandaRequest(token, accountID).account(accountID).order(orderParams).create
  end

  def self.oandaCancel(token, accountID, orderID)
    oandaRequest(token, accountID).account(accountID).order(orderID).cancel
  end

  def self.oandaCancelTrade(token, accountID, tradeID)
    oandaRequest(token, accountID).account(accountID).trade(tradeID).cancel
  end

  def self.oandaOrder(token, accountID, orderID)
    oandaRequest(token, accountID).account(accountID).order(orderID).show
  end

  def self.oandaTrade(token, accountID, tradeID)
    oandaRequest(token, accountID).account(accountID).trade(tradeID).show
  end

   def self.oandaUpdateTrade(tvData, token, accountID, tradeID, orderParams, tradeX)
    trailSet = oandaRequest(token, accountID).account(accountID).trade(tradeID, orderParams).update
    madeRecord = tradeX.take_profits.create!(ticker: tvData['ticker'], traderID: tvData['traderID'], uuid: trailSet['stopLossOrderTransaction']['id'], status: 'open', direction: tvData['direction'], broker: tvData['broker'], user_id: User.find_by(oandaToken: token).id)
    trailSet
  end

  def self.closePosition(token, accountID, tvData, tradeX, tradeInfo, reduceOrKill)
    traderFound = User.find_by(oandaToken: token)
    oandaTicker = "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}"
    if tvData['direction'] == 'sell'
      if reduceOrKill == 'reduce'
        unitsForOrder = (tvData['direction'] == 'sell' ?  (tradeInfo['trade']['initialUnits'].to_f * (0.01 * traderFound&.reduceBy)).round.abs : "-#{(tradeInfo['trade']['initialUnits'].to_f * (0.01 * traderFound&.reduceBy)).round}")
        options = {'shortUnits' => unitsForOrder}
      elsif reduceOrKill == 'kill'      
        options = {'shortUnits' => 'ALL'}
      end
    end

    if tvData['direction'] == 'buy'
      if reduceOrKill == 'reduce'
        unitsForOrder = (tvData['direction'] == 'sell' ?  (tradeInfo['trade']['initialUnits'].to_f * (0.01 * traderFound&.reduceBy)).round.abs : "-#{(tradeInfo['trade']['initialUnits'].to_f * (0.01 * traderFound&.reduceBy)).round}")
        options = {'longUnits' => unitsForOrder}
      elsif reduceOrKill == 'kill'      
        options = {'longUnits' => 'ALL'}
      end
    end
    debugger
    requestProfit = oandaRequest(token, accountID).account(accountID).position(oandaTicker, options).close
    if requestProfit.present? && requestProfit['orderCreateTransaction'].present?
      tradeX.take_profits.create!(ticker: tvData['ticker'], profitLoss: tvData['direction'] == 'sell' ?  requestProfit['shortOrderFillTransaction']['pl'] : requestProfit['longOrderFillTransaction']['pl'], traderID: tvData['traderID'], uuid: tvData['direction'] == 'sell' ?  requestProfit['shortOrderFillTransaction']['id'] : requestProfit['longOrderFillTransaction']['id'], status: 'closed', direction: tvData['direction'], broker: tvData['broker'], user_id: User.find_by(oandaToken: token).id)
     end
     
    requestProfit

  end

  def self.oandaTakeProfit(tvData, tradeInfo, token, accountID, tradeX, reduceOrKill)
    requestProfit = nil
    traderFound = User.find_by(oandaToken: token)
    trailPrice = tvData['currentPrice'].to_f.round(4) 

    if reduceOrKill == 'reduce'
      unitsForOrder = (tvData['direction'] == 'sell' ?  (tradeInfo['trade']['initialUnits'].to_f * (0.01 * traderFound&.reduceBy)).round.abs : "-#{(tradeInfo['trade']['initialUnits'].to_f * (0.01 * traderFound&.reduceBy)).round}")
    elsif reduceOrKill == 'kill'      
      unitsForOrder = (tvData['direction'] == 'sell' ?  (tradeInfo['trade']['currentUnits'].to_f * (0.01 * traderFound&.reduceBy)).round.abs : "-#{(tradeInfo['trade']['currentUnits'].to_f * (0.01 * traderFound&.reduceBy)).round}")
    end

    oandaOrderParams = {
      'order' => {
        'price' => trailPrice,
        'units' => unitsForOrder,
        'instrument' => "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}",
        'timeInForce' => 'GTC',
        'type' => 'LIMIT',
        'positionFill' => 'DEFAULT'
      }
    }
    requestProfit = Oanda.oandaEntry(token, accountID, oandaOrderParams)

    if requestProfit.present? && requestProfit['orderCreateTransaction'].present?
      tradeX.take_profits.create!(ticker:tvData['ticker'], traderID: tvData['traderID'], uuid: requestProfit['orderCreateTransaction']['id'], status: 'open', direction: tvData['direction'], broker: tvData['broker'], user_id: User.find_by(oandaToken: token).id)
     end
    requestProfit
  end

  def self.oandaRisk(tvData, token, accountID)
    # return number of units to buy
    traderFound = User.find_by(oandaToken: token)

    currentPrice = tvData['currentPrice'].to_f

    accountBalance = Oanda.oandaBalance(token, accountID)
    marginRate = Oanda.oandaAccount(token, accountID)['account']['marginRate'].to_f

    # return units
    unitsRisk = (((traderFound&.perEntry * 0.01) * accountBalance).to_f > marginRate ? ((traderFound&.perEntry * 0.01) * accountBalance).to_f / marginRate : 1.to_f * marginRate)
  end
end
