class Oanda < ApplicationRecord

	AccountID = '001-001-7086038-005'

	def self.oandaRequest(token)
		@oanda = OandaApiV20.new(access_token: token)
	end

	def self.oandaAccount(token)
		oandaRequest(token).account(AccountID).show
	end

	def self.oandaBalance(token)
		accountToFind = Oanda.oandaAccount(ENV['oandaToken'])

		accountBalance = accountToFind['account']['balance'].to_f
	end

	def self.oandaEntry(token,orderParams)
		oandaRequest(token).account(AccountID).order(orderParams).create
	end

	def self.oandaTrail(token)
		oandaRequest(token).account(AccountID).open_trades.show

		options = {
			'takeProfit' => {
			  'timeInForce' => 'GTC',
			  'price' => '2.5'
			}
		}
		oandaRequest(token).account(AccountID).order(id, options).update
	end
	
	def self.takeProfit(token)
		id = client.account(AccountID).open_trades.show['trades'][0]['id']
		options = { 'units' => '10' }
		oandaRequest(token).account(AccountID).trade(id, options).close
	end

	def self.oandaRisk(tvData, token, accountID = nil)
		#return number of units to buy
		currentPrice = tvData['currentPrice'].to_f

		accountBalance = Oanda.oandaBalance(ENV['oandaToken'])
		marginRate = Oanda.oandaAccount(ENV['oandaToken'])['account']['marginRate'].to_f

  	# return units
  	unitsRisk = (((tvData['perEntry'].to_f * 0.01) * accountBalance).to_f > marginRate ? ((tvData['perEntry'].to_f * 0.01) * accountBalance).to_f  / marginRate : (1).to_f * marginRate)
	end
end

