class Oanda < ApplicationRecord
	@oanda = OandaApiV20.new(access_token: ENV['oandaToken'])

	def self.accounts
		@oanda.accounts.show['accounts']
	end

	def self.balance
		@oanda.accounts.show['accounts']
	end

	def self.entry #limit&market
		options = {
		  'order' => {
		    'units' => '100',
		    'instrument' => 'EUR_CAD',
		    'timeInForce' => 'FOK',
		    'type' => 'MARKET',
		    'positionFill' => 'DEFAULT'
		  },
		}
		@oanda.account('account_id').order(options).create
	end

	def self.trail
		@oanda.account('account_id').open_trades.show

		options = {
			'takeProfit' => {
			  'timeInForce' => 'GTC',
			  'price' => '2.5'
			}
		}
		@oanda.account('account_id').order(id, options).update
	end
	
	def self.takeProfit
		id = client.account('account_id').open_trades.show['trades'][0]['id']
		options = { 'units' => '10' }
		@oanda.account('account_id').trade(id, options).close
	end
end

