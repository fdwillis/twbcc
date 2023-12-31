class SourcesController < ApplicationController
	def index
		
	end

	def new
		
	end
	
	def create
		begin
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
		rescue Stripe::StripeError => e
      session['coupon'] = nil
      flash[:error] = e.error.message.to_s
      redirect_to request.referrer
    rescue Exception => e
      session['coupon'] = nil
      flash[:error] = e.to_s
      redirect_to request.referrer
    end
	end

	private

	def setCardVarParams
    paramsClean = params.require(:newSource).permit(:number, :cvc, :exp_month, :exp_year, :cvc)
    paramsClean.reject { |_, v| v.blank? }
  end
end