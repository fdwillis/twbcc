class Trade < ApplicationRecord
	has_many :take_profits, dependent: :delete_all
end
