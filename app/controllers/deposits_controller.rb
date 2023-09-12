class DepositsController < ApplicationController
	before_action :authenticate_user!

	def index
		
	end

	def new
		
		@sources = Stripe::Customer.list_sources(current_user.stripeCustomerID)[:data]
	end
	
	def create
		debugger

	end
end