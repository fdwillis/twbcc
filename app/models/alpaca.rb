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

	def self.getBalance
		getAccount['buying_power']
	end
end

def self.xpercentForTradeFromTimeframe(tvData)
	# get dynamic min for
	currentPrice = tvData['currentPrice'].to_f
	
	if tvData['tickerType'] == 'stock' && tvData['broker'] == 'alpaca'
		accountBalance = getBalance
	end
	
  ((tvData['perEntry'].to_f * 0.01) * accountBalance).to_f
end

# alpaca entries: needs to accept trailing so that we can place fractional orders where traders set the bounds. 

# new entries
# trail profitable positions
# pull open orders
# trade history
# query specific trade/order
