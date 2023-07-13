class Tradiers < ApplicationRecord

  def self.tradierRequest(token)
		@tradier = Tradier::Client.new(access_token: token)
  end

  def self.tradierStock(symbol, token)
		 tradierRequest(token).quote(symbol.upcase)
  end

	def self.optionsXFriday(symbol,token, interval)
		 tradierRequest(token).chain(symbol.upcase, expiration: Tradiers.upcomingFriday(interval))
	end

	def self.upcomingFriday(interval)
		# allow to pull from multiple weeks out
		intervalCount = 0
		firstdate = Date.today.strftime("%Y-%m-%d")

		(interval + 1).times do 
			firstdate = firstdate.to_date.next_occurring(:friday).strftime("%Y-%m-%d")
			intervalCount += 1
		end

		firstdate
	end
end