class Tradier < ApplicationRecord
	def self.upcomingFriday
		Date.today.next_occurring(:friday)
	end
end