class DepositsController < ApplicationController
	before_action :authenticate_user!

	def index
		
	end

	def new
		
		@sources = Stripe::Customer.list_sources(current_user.stripeCustomerID)[:data]
	end
	
	def create
		begin
			stripeCustomerX = Stripe::Customer.retrieve(current_user&.stripeCustomerID)
	    cardHolderID = stripeCustomerX['metadata']['cardHolder'].strip
	    cardholder = Stripe::Issuing::Cardholder.retrieve(cardHolderID)
	    loadSpendingMeta = cardholder['spending_controls']['spending_limits']
			
			chargeX = Stripe::Charge.create({
				amount: User.stripeAmount((newDepositRequest[:depositAmount].to_f + newDepositRequest[:depositAmount].to_f * 0.05).to_s),
				currency: 'usd',
				source: newDepositRequest[:depositSource],
				description: "Deposit $#{(User.stripeAmount(newDepositRequest[:depositAmount]) * 0.01).to_i}",
				customer: current_user&.stripeCustomerID,
				metadata: {requestAmount: User.stripeAmount(newDepositRequest[:depositAmount])}
			})

			amountForFee = Stripe::BalanceTransaction.retrieve(chargeX['balance_transaction'])['net'] - chargeX['metadata']['requestAmount'].to_i

			if amountForFee >= 1
				transferX = Stripe::Transfer.create({
			      amount: amountForFee,
			      currency: 'usd',
			      destination: ENV['oarlinStripeAccount'],
			      description: 'Deposit Fee',
			      source_transaction: chargeX['id']
			    })
			end

			amountForIssue = Stripe::BalanceTransaction.retrieve(chargeX['balance_transaction'])['net'] - amountForFee.to_i

	    topUp = Stripe::Topup.create({
	      amount: amountForIssue,
	      currency: 'usd',
	      description: "#{stripeCustomerX.id} deposit: $#{(amountForIssue).to_f * 0.01}",
	      statement_descriptor: 'Top-up',
	      destination_balance: 'issuing',
	      metadata: {cardHolder: stripeCustomerX['metadata']['cardHolder'], deposit: true}
	    })

	    Stripe::Charge.update(chargeX.id, metadata: {topUp: topUp['id']})
	      
			someCalAmount = loadSpendingMeta.empty? ? amountForIssue : loadSpendingMeta&.first['amount'].to_i + amountForIssue
	    
	    case loadSpendingMeta&.empty?
	    when true
	      Stripe::Issuing::Cardholder.update(cardHolderID,{spending_controls: {spending_limits: [amount: amountForIssue, interval: 'per_authorization']}})
	    when false 
	      Stripe::Issuing::Cardholder.update(cardHolderID,{spending_controls: {spending_limits: [amount: someCalAmount, interval: 'per_authorization']}})
	    end
	    
	    Stripe::Issuing::Card.update(stripeCustomerX['metadata']['issuedCard'].strip, status: 'active')








			flash[:success] = "Deposit Submitted"
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

	def newDepositRequest
    paramsClean = params.require(:newDepositRequest).permit(:depositAmount, :depositSource)
    paramsClean.reject { |_, v| v.blank? }
  end
end
