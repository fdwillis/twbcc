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

	def self.oandaTrail(token, accountID)
		oandaRequest(token, accountID).account(accountID).open_trades.show

		options = {
			'takeProfit' => {
			  'timeInForce' => 'GTC',
			  'price' => '2.5'
			}
		}
		oandaRequest(token, accountID).account(accountID).order(id, options).update
	end
	
	def self.takeProfit(token, accountID)
		id = client.account(accountID).open_trades.show['trades'][0]['id']
		options = { 'units' => '10' }
		oandaRequest(token, accountID).account(accountID).trade(id, options).close
	end

	def self.oandaRisk(tvData, token, accountID)
		#return number of units to buy
		currentPrice = tvData['currentPrice'].to_f

		accountBalance = Oanda.oandaBalance(token, accountID)
		marginRate = Oanda.oandaAccount(token, accountID)['account']['marginRate'].to_f

  	# return units
  	unitsRisk = (((tvData['perEntry'].to_f * 0.01) * accountBalance).to_f > marginRate ? ((tvData['perEntry'].to_f * 0.01) * accountBalance).to_f  / marginRate : (1).to_f * marginRate)
	end
end

