class Tradiers < ApplicationRecord

  def self.tradierRequest(token)
		@tradier = Tradier::Client.new(access_token: ENV['tradierToken'])
  end

	def self.optionsThisFriday(symbol,token)
		 tradierRequest(token).chain(symbol.upcase, expiration: Tradiers.upcomingFriday)
	end

	def self.upcomingFriday
		Date.today.next_occurring(:friday).strftime("%Y-%m-%d")
	end
end