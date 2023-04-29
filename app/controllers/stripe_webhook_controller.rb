class StripeWebhooksController < ApplicationController

  def update
    event = params['stripe_webhook']['type']
    stripeObject = params['data']['object']

    if event == 'checkout.session.completed'
      #update referredBy from custom field onto the stripe customer ID
      #mark payment as split between affiliate if referredBy is present
    end
  end
end