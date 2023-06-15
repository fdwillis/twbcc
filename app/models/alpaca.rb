class Alpaca < ApplicationRecord
	def self.getStock(symbol)
		api_id = ENV["alpacaKey"]
		api_key = ENV["alpacaSecret"]

		curlCall = `curl -H "APCA-API-KEY-ID: #{ENV['alpacaKey']}" -H "APCA-API-SECRET-KEY: #{ENV['alpacaSecret']}" -d "" -X GET https://api.alpaca.markets/v2/assets/#{symbol}`

		response = Oj.load(curlCall)
		
	end

	def self.currentPositions
		api_id = ENV["alpacaKey"]
		api_key = ENV["alpacaSecret"]

		curlCall = `curl -H "APCA-API-KEY-ID: #{ENV['alpacaKey']}" -H "APCA-API-SECRET-KEY: #{ENV['alpacaSecret']}" -d "" -X GET https://api.alpaca.markets/v2/orders?status=closed`

		response = Oj.load(curlCall)
		
	end

	def self.getAccount
		# account balance
		api_id = ENV["alpacaKey"]
		api_key = ENV["alpacaSecret"]

		curlCall = `curl -H "APCA-API-KEY-ID: #{ENV['alpacaKey']}" -H "APCA-API-SECRET-KEY: #{ENV['alpacaSecret']}" -d "" -X GET https://api.alpaca.markets/v2/account`

		response = Oj.load(curlCall)
	end
end

# alpaca entries: needs to accept trailing so that we can place fractional orders where traders set the bounds. 

# calculate units
# new entries
# trail profitable positions
# pull open orders
# query ticker info
# trade history
# query specific trade
