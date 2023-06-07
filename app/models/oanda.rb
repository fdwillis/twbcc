class Oanda < ApplicationRecord
	@oanda = OandaApiV20.new(access_token: ENV['oandaToken'])
	def self.accounts
		@oanda.accounts.show['accounts']
	end
end