class StripeWebhooksController < ApplicationController
  protect_from_forgery with: :null_session

  def update
    event = params['stripe_webhook']['type']

    if event == 'checkout.session.completed'
      # send sessionLinkEmail: after payment
      ApplicationMailer.sessionLink(stripeObject['id']).deliver_now
    end

    if event == 'issuing_authorization.request'
      stripeObject = params['data']['object']
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
