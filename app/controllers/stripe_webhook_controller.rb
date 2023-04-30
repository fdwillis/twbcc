class StripeWebhooksController < ApplicationController

  def update
    event = params['stripe_webhook']['type']
    stripeObject = params['data']['object']

    if event == 'invoice.paid'
      #pay affiliate -> if affilaite active & current
      #restore access membership | addons
    elsif event == 'invoice.payment_failed'
      #remove access membership | addons
    elsif event == 'charge.succeeded' #connect account makes sale
      # take 2% application fee
    end
  end
end