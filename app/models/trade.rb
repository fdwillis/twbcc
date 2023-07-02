class Trade < ApplicationRecord
	has_many :take_profits
	belongs_to :user
end
