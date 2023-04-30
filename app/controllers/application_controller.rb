class ApplicationController < ActionController::Base

	def home
		@products = User.rainforestProduct
		@categories = User.rainforestSearch
	end

	def membership
		customFields = [{
			key: 'type',
			label: {custom: 'Account Type', type: 'custom'},
			type: 'dropdown',
			dropdown: {options: [
				{label: 'Individual', value: 'individual'},
				{label: 'Company', value: 'company'},
			]}},{
			key: 'country',
			label: {custom: 'Country', type: 'custom'},
			type: 'dropdown',
			dropdown: {options: [
				{label: 'Australia', value: 'AU'},
				{label: 'Belgium', value: 'BE'},
				{label: 'Brazil', value: 'BR'},
				{label: 'Canada', value: 'CA'},
				{label: 'China', value: 'CN'},
				{label: 'France', value: 'FR'},
				{label: 'Germany', value: 'DE'},
				{label: 'India', value: 'IN'},
				{label: 'Italy', value: 'IT'},
				{label: 'Japan', value: 'JP'},
				{label: 'Mexico', value: 'MX'},
				{label: 'Netherlands', value: 'NL'},
				{label: 'Poland', value: 'PL'},
				{label: 'Saudi Arabia', value: 'SA'},
				{label: 'Singapore', value: 'SG'},
				{label: 'Spain', value: 'ES'},
				{label: 'Sweden', value: 'SE'},
				{label: 'United Arab Emirates', value: 'AE'},
				{label: 'United Kingdom', value: 'GB'},
				{label: 'United States', value: 'US'},
			]}
		}]
		allowedCountries = [
	      	'AU',
	      	'BE',
	      	'BR',
	      	'CA',
	      	'CN',
	      	'FR',
	      	'DE',
	      	'IN',
	      	'IT',
	      	'JP',
	      	'MX',
	      	'NL',
	      	'PL',
	      	'SA',
	      	'SG',
	      	'ES',
	      	'SE',
	      	'AE',
	      	'GB',
	      	'US',
	      ]
	  successURL = "http://#{request.env['HTTP_HOST']}/new-password-set?session={CHECKOUT_SESSION_ID}&referredBy=#{params['referredBy']}"
		# free -> build on page, 
		# affiliate, 
		@freeMembership = Stripe::Checkout::Session.create({
      success_url: successURL,
      custom_fields: customFields,
      phone_number_collection: {
	      enabled: true
	    },
      shipping_address_collection: {allowed_countries: allowedCountries},
      line_items: [
        {price: ENV['freeMembership'], quantity: 1},
      ],
      mode: 'subscription',
    })

    @affiliateMonthly = Stripe::Checkout::Session.create({
      success_url: successURL,
      custom_fields: customFields,
      phone_number_collection: {
	      enabled: true
	    },
      shipping_address_collection: {allowed_countries: allowedCountries},
      line_items: [
        {price: ENV['affiliateMonthly'], quantity: 1},
      ],
      mode: 'subscription',
    })
    @affiliateAnnual = Stripe::Checkout::Session.create({
      success_url: successURL,
      custom_fields: customFields,
      phone_number_collection: {
		      enabled: true
		    },
      shipping_address_collection: {allowed_countries: allowedCountries},
      line_items: [
        {price: ENV['affiliateAnnual'], quantity: 1},
      ],
      mode: 'subscription',
    })
		# business,
		@businessMonthly = Stripe::Checkout::Session.create({
      success_url: successURL,
      custom_fields: customFields,
      phone_number_collection: {
	      enabled: true
	    },
      shipping_address_collection: {allowed_countries: allowedCountries},
      line_items: [
        {price: ENV['businessMonthly'], quantity: 1},
      ],
      mode: 'subscription',
    })
    @businessAnnual = Stripe::Checkout::Session.create({
      success_url: successURL,
      custom_fields: customFields,
      phone_number_collection: {
		      enabled: true
		    },
      shipping_address_collection: {allowed_countries: allowedCountries},
      line_items: [
        {price: ENV['businessAnnual'], quantity: 1},
      ],
      mode: 'subscription',
    }) 

    @automationMonthly = Stripe::Checkout::Session.create({
      success_url: successURL,
      custom_fields: customFields,
      phone_number_collection: {
		      enabled: true
		    },
      shipping_address_collection: {allowed_countries: allowedCountries},
      line_items: [
        {price: ENV['automationMonthly'], quantity: 1},
      ],
      mode: 'subscription',
    }) 
    @automationAnnual = Stripe::Checkout::Session.create({
      success_url: successURL,
      custom_fields: customFields,
      phone_number_collection: {
		      enabled: true
		    },
      shipping_address_collection: {allowed_countries: allowedCountries},
      line_items: [
        {price: ENV['automationAnnual'], quantity: 1},
      ],
      mode: 'subscription',
    }) 
		# custom -> build on page, 
	end


	def profile
		@profile = current_user.present? ? {stripeCustomer: Stripe::Customer.retrieve(current_user.stripeCustomerID), membershipInfo: current_user.checkMembership} : {stripeCustomer: Stripe::Customer.retrieve(User.find_by(uuid: params['id']).stripeCustomerID), membershipInfo:  User.find_by(uuid: params['id']).checkMembership}
		
		if current_user
			validMembership = current_user.checkMembership
			@stripeAccountUpdate = Stripe::AccountLink.create(
			  {
			    account: Stripe::Customer.retrieve(current_user.stripeCustomerID)['metadata']['connectAccount'],
			    refresh_url: "http://#{request.env['HTTP_HOST']}",
			    return_url: "http://#{request.env['HTTP_HOST']}",
			    type: 'account_onboarding',
			  },
			)

			@itemsDue = Stripe::Account.retrieve(Stripe::Customer.retrieve(current_user.stripeCustomerID)['metadata']['connectAccount'])['requirements']['currently_due']
		end
	end

	def tracking
		if current_user&.present?
			customerToUpdate = Stripe::Customer.retrieve(current_user&.stripeCustomerID)
			@tracking = customerToUpdate['metadata']['tracking'].present? ? customerToUpdate['metadata']['tracking'].split(',').uniq : nil
		end
		if request.post?
			if params[:id].present?
				customerUpdated = Stripe::Customer.update(current_user.stripeCustomerID,{
					metadata: {
						tracking: customerToUpdate['metadata']['tracking'].present? ? (customerToUpdate['metadata']['tracking']+"#{params[:id]},") : "#{params[:id]},"
					}
				})
				flash[:success] = 'Added To Your Tracking List'
				redirect_to request.referrer
			end
		end
	end
	
	def wishlist
		if current_user&.present?
			customerToUpdate = Stripe::Customer.retrieve(current_user.stripeCustomerID)
			@wishlist = customerToUpdate['metadata']['wishlist'].present? ? customerToUpdate['metadata']['wishlist'].split(',').uniq : nil
		end
		if request.post?
			if params[:id].present?
				customerUpdated = Stripe::Customer.update(current_user.stripeCustomerID,{
					metadata: {
						wishlist: customerToUpdate['metadata']['wishlist'].present? ? (customerToUpdate['metadata']['wishlist']+"#{params[:id]},") : "#{params[:id]},"
					}
				})
				flash[:success] = 'Added To Your Wishlist'
				redirect_to request.referrer
			end
		end
	end

	def how_it_works
		
	end
end
















