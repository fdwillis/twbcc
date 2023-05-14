require 'will_paginate/array'
class Category < ApplicationRecord
	extend FriendlyId
  friendly_id :title, use: :slugged
end
