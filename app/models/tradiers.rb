class Tradiers < ApplicationRecord

  def self.tradierRequest(token)
		@tradier = Tradier::Client.new(access_token: token)
  end

  def self.tradierStock(symbol, token)
		 tradierRequest(token).quote(symbol.upcase)
  end

	def self.optionsThisFriday(symbol,token)
		 tradierRequest(token).chain(symbol.upcase, expiration: Tradiers.upcomingFriday)
	end

	def self.upcomingFriday
		# allow to pull from multiple weeks out
		Date.today.next_occurring(:friday).strftime("%Y-%m-%d")
	end
end