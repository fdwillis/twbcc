class SourcesController < ApplicationController
	def index
		
	end

	def new
		
	end
	
	def create
		tokenX = Stripe::Token.create({
		  card: {
		    number: setCardVarParams[:number],
		    exp_month: setCardVarParams[:exp_month],
		    exp_year: setCardVarParams[:exp_year],
		    cvc: setCardVarParams[:cvc],
		  },
		})

		Stripe::Customer.create_source(
		  current_user&.stripeCustomerID,
		  {source: tokenX},
		)
		flash[:notice] = "Source Added"
		redirect_to new_deposit_path
	end

	private

	def setCardVarParams
    paramsClean = params.require(:newSource).permit(:number, :cvc, :exp_month, :exp_year, :cvc)
    paramsClean.reject { |_, v| v.blank? }
  end
end