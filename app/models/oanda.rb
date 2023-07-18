class Oanda < ApplicationRecord
  def self.oandaRequest(token, accountID)
    @oanda = OandaApiV20.new(access_token: token)
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
    madeRecord = tradeX.take_profits.create!(traderID: tvData['traderID'], uuid: trailSet['stopLossOrderTransaction']['id'], status: 'open', direction: tvData['direction'], broker: tvData['broker'], user_id: User.find_by(oandaToken: token).id)
    trailSet
  end

  def self.closePosition(token, accountID, oandaTicker, tvData)
    if tvData['direction'] == 'sell'
      options = {'shortUnits' => 'ALL'}
    end

    if tvData['direction'] == 'buy'
      options = {'longUnits' => 'ALL'}
    end
    requestProfit = oandaRequest(token, accountID).account(accountID).position(oandaTicker, options).close

    if requestProfit.present? && requestProfit['orderCreateTransaction'].present?
      # cost: requestProfit['orderFillTransaction']['tradeOpened']['initialMarginRequired'].to_f,
      tradeX.take_profits.create!(traderID: tvData['traderID'], uuid: requestProfit['orderCreateTransaction']['id'], status: 'open', direction: tvData['direction'], broker: tvData['broker'], user_id: User.find_by(oandaToken: token).id)
      
      tvData['ticker'] = tvData['ticker'].delete("_")
     end
    requestProfit

  end

  def self.oandaTakeProfit(tvData, tradeInfo, token, accountID, tradeX, reduceOrKill)
    requestProfit = nil
    traderFound = User.find_by(oandaToken: token)
    trailPrice = tvData['currentPrice'].to_f.round(5) 

    if reduceOrKill == 'reduce'
      unitsForOrder = (tvData['type'] == 'sellStop' ?  (tradeInfo['trade']['initialUnits'].to_f * (0.01 * traderFound&.reduceBy)).round.abs.to_s : "-#{(tradeInfo['trade']['initialUnits'].to_f * (0.01 * traderFound&.reduceBy)).round}")
    elsif reduceOrKill == 'kill'      
      unitsForOrder = (tvData['type'] == 'sellStop' ?  (tradeInfo['trade']['currentUnits'].to_f * (0.01 * traderFound&.reduceBy)).round.abs.to_s : "-#{(tradeInfo['trade']['currentUnits'].to_f * (0.01 * traderFound&.reduceBy)).round}")
    end

    oandaOrderParams = {
      'order' => {
        'price' => trailPrice,
        'units' => unitsForOrder,
        'instrument' => tvData['ticker'].insert(3, '_'),
        'timeInForce' => 'GTC',
        'type' => 'LIMIT',
        'positionFill' => 'DEFAULT'
      }
    }

    requestProfit = Oanda.oandaEntry(token, accountID, oandaOrderParams)

    if requestProfit.present? && requestProfit['orderCreateTransaction'].present?
      # cost: requestProfit['orderFillTransaction']['tradeOpened']['initialMarginRequired'].to_f,
      tradeX.take_profits.create!(traderID: tvData['traderID'], uuid: requestProfit['orderCreateTransaction']['id'], status: 'open', direction: tvData['direction'], broker: tvData['broker'], user_id: User.find_by(oandaToken: token).id)
      
      tvData['ticker'] = tvData['ticker'].delete("_")
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
