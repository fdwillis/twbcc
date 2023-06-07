class Alpaca < ApplicationRecord
	def self.getStock(symbol)
		api_id = ENV["alpacaKey"]
		api_key = ENV["alpacaSecret"]

		curlCall = `curl -H "APCA-API-KEY-ID: #{ENV['alpacaKey']}" -H "APCA-API-SECRET-KEY: #{ENV['alpacaSecret']}" -d "" -X GET https://api.alpaca.markets/v2/assets/#{symbol}`

		response = Oj.load(curlCall)
		
	end

	def self.positions
		api_id = ENV["alpacaKey"]
		api_key = ENV["alpacaSecret"]

		curlCall = `curl -H "APCA-API-KEY-ID: #{ENV['alpacaKey']}" -H "APCA-API-SECRET-KEY: #{ENV['alpacaSecret']}" -d "" -X GET https://api.alpaca.markets/v2/orders?status=closed`

		response = Oj.load(curlCall)
		
	end
end