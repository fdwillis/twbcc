class DepositsController < ApplicationController
	before_action :authenticate_user!

	def index
		
	end

	def new
		
		@sources = Stripe::Customer.list_sources(current_user.stripeCustomerID)[:data]
	end
	
	def create
		chargeX = Stripe::Charge.create({
			amount: User.stripeAmount((newDepositRequest[:depositAmount].to_f + newDepositRequest[:depositAmount].to_f * 0.05).to_s),
			currency: 'usd',
			source: newDepositRequest[:depositSource],
			description: 'TWBCC ',
			customer: current_user&.stripeCustomerID,
			metadata: {reqeustAmount: User.stripeAmount(newDepositRequest[:depositAmount])}
		})
		
		transferX = Stripe::Transfer.create({
      amount: Stripe::BalanceTransaction.retrieve(chargeX['balance_transaction'])['net'] - chargeX['metadata']['reqeustAmount'].to_i,
      currency: 'usd',
      destination: ENV['oarlinStripeAccount'],
      description: 'Deposit Fee',
      source_transaction: chargeX['id']
    })
		flash[:success] = "Deposit Submitted"
		redirect_to new_deposit_path
	end

	private

	def newDepositRequest
    paramsClean = params.require(:newDepositRequest).permit(:depositAmount, :depositSource)
    paramsClean.reject { |_, v| v.blank? }
  end
end
