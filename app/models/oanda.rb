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

  def self.oandaEntry(token, accountID, orderParams)
    oandaRequest(token, accountID).account(accountID).order(orderParams).create
  end

  def self.oandaCancel(token, accountID, orderID)
    oandaRequest(token, accountID).account(accountID).order(orderID).cancel
  end

  def self.oandaOrder(token, accountID, orderID)
    oandaRequest(token, accountID).account(accountID).order(orderID).show
  end

  def self.oandaTrade(token, accountID, tradeID)
    oandaRequest(token, accountID).account(accountID).trade(tradeID).show
  end

  def self.takeProfit(token, accountID)
    id = client.account(accountID).open_trades.show['trades'][0]['id']
    options = { 'units' => '10' }
    oandaRequest(token, accountID).account(accountID).trade(id, options).close
  end

  def self.oandaTrail(tvData, tradeInfo, token, accountID, tradeX)
    requestProfit = nil
    trailPrice =  (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(5) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(5)).to_s
    oandaOrderParams = {
      'order' => {
        'price' => trailPrice,
        'units' => tvData['type'] == 'sellStop' ?  tradeInfo['order']['units'] : "-#{tradeInfo['order']['units']}",
        'instrument' => tvData['ticker'].insert(3, '_'),
        'timeInForce' => 'GTC',
        'type' => 'LIMIT',
        'positionFill' => 'DEFAULT'
      }
    }

    # FINAL TESTING
    requestProfit = Oanda.oandaEntry(token, accountID, oandaOrderParams)

    if requestProfit.present? && requestProfit['orderCreateTransaction'].present?
      tradeX.take_profits.create!(uuid: requestProfit['orderCreateTransaction']['id'], status: 'open', direction: tvData['direction'], broker: tvData['broker'], user_id: User.find_by(oandaToken: token).id)
      requestProfit
     end
  end

  def self.oandaRisk(tvData, token, accountID)
    # return number of units to buy
    traderFound = User.find_by(oandaToken: apiKey)

    currentPrice = tvData['currentPrice'].to_f

    accountBalance = Oanda.oandaBalance(token, accountID)
    marginRate = Oanda.oandaAccount(token, accountID)['account']['marginRate'].to_f

    # return units
    unitsRisk = (((traderFound&.perEntry * 0.01) * accountBalance).to_f > marginRate ? ((traderFound&.perEntry * 0.01) * accountBalance).to_f / marginRate : 1.to_f * marginRate)
  end
end
