class Product < ApplicationRecord
	extend FriendlyId
	friendly_id :asin, use: :slugged
end
