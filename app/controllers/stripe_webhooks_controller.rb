class StripeWebhooksController < ApplicationController
  protect_from_forgery with: :null_session
  
  def update
    event = params['stripe_webhook']['type']
    stripeObject = params['data']['object']
    validMemberships = User::AUTOMATIONmembership+User::BUSINESSmembership+User::AFFILIATEmembership

    if event == 'invoice.paid'
      #pay affiliate -> if affilaite active & usd base
      stripeCustomer = Stripe::Customer.retrieve(stripeObject['customer'])
      if Stripe::Customer.retrieve(stripeObject['customer'])['metadata']['referredBy'].split(',').reject(&:blank?)[0].present?
        loadedAffililate = User.find_by(uuid: stripeCustomer['metadata']['referredBy'])
        subscriptionList = Stripe::Subscription.list({customer: loadedAffililate.stripeCustomerID})['data'].map(&:plan)
        stripeAffiliate = Stripe::Customer.retrieve(loadedAffililate.stripeCustomerID)
        affiliateConnectAccount = stripeAffiliate['metadata']['connectAccount']

        subscriptionList.each do |subscription|
          if validMemberships.include?(subscription['id']) && subscription['active'] == true && loadedAffililate&.amazonCountry == 'US'
            Stripe::Transfer.create({
              amount: (subscription['amount']*(stripeAffiliate['metadata']['commissionRate'].to_f/100)).to_i,
              currency: 'usd',
              destination: affiliateConnectAccount,
              description: "Membership Commission",
              source_transaction: stripeObject['charge']
            })
          end
        end
      end
    end
  end
end