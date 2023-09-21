class StripeWebhooksController < ApplicationController
  protect_from_forgery with: :null_session
  #   ApplicationMailer.sessionLink(stripeObject['id']).deliver_now

  def update
    event = params['stripe_webhook']['type']
    stripeObject = params['data']['object']

    if event == 'charge.succeeded'
      if stripeObject['amount'] == 500
        transferX = Stripe::Transfer.create({
          amount: Stripe::BalanceTransaction.retrieve(stripeObject['balance_transaction'])['net'] - 350,
          currency: 'usd',
          destination: ENV['oarlinStripeAccount'],
          description: 'Card Printed',
          source_transaction: stripeObject['id']
        })
        render json: {
          success: true
        }
        return
      else
        transferX = Stripe::Transfer.create({
          amount: (stripeObject['amount'] * 0.02).to_i,
          currency: 'usd',
          destination: ENV['oarlinStripeAccount'],
          description: "2% Transaction",
          source_transaction: stripeObject['id']
        })
        render json: {
          success: true
        }
        return
      end
    end

    if event == 'issuing_authorization.request'
      customerIDToGrab = stripeObject['card']['cardholder']['metadata']['stripeCustomerID']
      customerToGrab = Stripe::Customer.retrieve(customerIDToGrab)
      cardHolderID = customerToGrab['metadata']['cardHolder'].strip
      cardholder = Stripe::Issuing::Cardholder.retrieve(cardHolderID)
      loadSpendingMeta = cardholder['spending_controls']['spending_limits']

      amountToCharge = stripeObject['pending_request']['amount']
      maxSpend = loadSpendingMeta&.first['amount']
      authToProcess = stripeObject['id']
      
      if amountToCharge < maxSpend
        limitAfterAuth = maxSpend - amountToCharge
        if limitAfterAuth < 1
          Stripe::Issuing::Authorization.decline(authToProcess)
          render json: {
            success: false
          }
        else
          Stripe::Issuing::Authorization.approve(authToProcess)
          Stripe::Issuing::Cardholder.update(cardHolderID,{spending_controls: {spending_limits: [amount: limitAfterAuth, interval: 'per_authorization']}})
        end
      else
        Stripe::Issuing::Authorization.decline(authToProcess)
        render json: {
          success: false
        }
      end
    end
  end
end








