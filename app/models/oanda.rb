class Oanda < ApplicationRecord

	def self.oandaRequest(token)
		@oanda = OandaApiV20.new(access_token: token)
	end

	def self.accounts(token)
		oandaRequest(token).accounts.show['accounts']
	end

	def self.balance(token)
		oandaRequest(token).accounts.show['accounts']
	end

	def self.entry(token, orderParams) #limit&market
		oandaRequest(token).account('account_id').order(orderParams).create
	end

	def self.trail(token)
		oandaRequest(token).account('account_id').open_trades.show

		options = {
			'takeProfit' => {
			  'timeInForce' => 'GTC',
			  'price' => '2.5'
			}
		}
		oandaRequest(token).account('account_id').order(id, options).update
	end
	
	def self.takeProfit(token)
		id = client.account('account_id').open_trades.show['trades'][0]['id']
		options = { 'units' => '10' }
		oandaRequest(token).account('account_id').trade(id, options).close
	end
end

