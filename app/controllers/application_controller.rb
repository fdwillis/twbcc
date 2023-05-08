class ApplicationController < ActionController::Base
	before_action :authenticate_user!, only: [:loved] 

	def home
		@products = User.rainforestProduct
		@categories = User.rainforestSearch
	end

	def cancel
		allSubscriptions = Stripe::Subscription.list({customer: current_user&.stripeCustomerID})['data'].map(&:id)
		allSubscriptions.each do |id|
			Stripe::Subscription.cancel(id)
		end

		Stripe::Subscription.create({
		  customer: current_user&.stripeCustomerID,
		  items: [
		    {price: ENV['freeMembership']},
		  ],
		})

		flash[:success] = "Membership Canceled"
		redirect_to request.referrer
	end

	def commissions
		@pulledAffiliate = Stripe::Customer.retrieve(User.find_by(uuid: params[:id])&.stripeCustomerID)
		@pulledCommissions = Stripe::Customer.list(limit: 100)
		@accountsFromAffiliate = @pulledCommissions['data'].reject{|e| e['metadata']['referredBy'] != params[:id]}
		@activeSubs = []
		@inactiveSubs = []
		@accountsFromAffiliate.each do |cusID|
	  	listofSubscriptionsFromCusID = Stripe::Subscription.list(limit: 100, customer: cusID)['data']
	    if listofSubscriptionsFromCusID.size > 0 
		  	listofSubscriptionsFromCusID.each do |subscriptionX| 
		    	# debugger
			  	if subscriptionX['status'] == 'active' 
			  		@activeSubs << subscriptionX
			  	else
			  		@inactiveSubs << subscriptionX
			  	end
		  	end
	  	end
		end
		@expectedAnnualCommission = 0

		@activeSubs.each do |suba|
			suba['items']['data'].map(&:plan).each do |plan|
				if plan['interval'] == 'month'
					
					@expectedAnnualCommission += (plan['amount'] * 12) * (@pulledAffiliate['metadata']['commissionRate'].to_i * 0.01)
				end

				if plan['interval'] == 'year'
					
					@expectedAnnualCommission += (plan['amount']) * (@pulledAffiliate['metadata']['commissionRate'].to_i * 0.01)
				end

			end
		end

		
	end

	def analytics
		
	end
# <%= Ahoy::Event.where_event("Search Terms").count %>
	def checkout
		applicationFeeAmount = Stripe::Price.retrieve(params['price'],{stripe_account: params['account']})['unit_amount'] * 0.02
		@session = Stripe::Checkout::Session.create({
			success_url: "http://#{request.env['HTTP_HOST']}",
      phone_number_collection: {
	      enabled: true
	    },
	    payment_intent_data: {
	    	application_fee_amount: applicationFeeAmount.to_i
	    },
      line_items: [
        {price: params['price'], quantity: 1},
      ],
      mode: 'payment',
    }, {stripe_account: params['account']})

    redirect_to @session['url']
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
				{label: 'Canada', value: 'CA'},
				{label: 'France', value: 'FR'},
				{label: 'Germany', value: 'DE'},
				{label: 'Italy', value: 'IT'},
				{label: 'Japan', value: 'JP'},
				{label: 'Mexico', value: 'MX'},
				{label: 'Netherlands', value: 'NL'},
				{label: 'Poland', value: 'PL'},
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
	      	'CA',
	      	'FR',
	      	'DE',
	      	'IT',
	      	'JP',
	      	'MX',
	      	'NL',
	      	'PL',
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
		@userFound = current_user.present? ? current_user : User.find_by(uuid: params['id'])
		@profile = Stripe::Customer.retrieve(@userFound.stripeCustomerID)
		@membershipDetails = @userFound.checkMembership
		@profileMetadata = @profile['metadata']

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

			@accountItemsDue = Stripe::Account.retrieve(Stripe::Customer.retrieve(current_user.stripeCustomerID)['metadata']['connectAccount'])['requirements']['currently_due']
			
			# if current_user&.amazonCountry != 'US'
			# 	@recipientAccountUpdate = Stripe::AccountLink.create(
			# 	  {
			# 	    account: Stripe::Customer.retrieve(current_user.stripeCustomerID)['metadata']['connectAccount'],
			# 	    refresh_url: "http://#{request.env['HTTP_HOST']}",
			# 	    return_url: "http://#{request.env['HTTP_HOST']}",
			# 	    type: 'account_onboarding',
			# 	  },
			# 	)

			# 	@recipientAccountItemsDue = Stripe::Account.retrieve(Stripe::Customer.retrieve(current_user.stripeCustomerID)['metadata']['recipientAccount'])['requirements']['currently_due']
			# end
		else
			#analytics
			ahoy.track "Profile Visit", user: @userFound.uuid
		end
		
		if @membershipDetails.present? && @membershipDetails[:membershipDetails][:active]	
		  #custom profile if active
		  if @membershipDetails[:membershipType] == 'automation' && !current_user
		  	fileToFind = ("app/views/automation/#{@userFound.uuid}.html.erb")
		  	
		  	if customFile = File.exist?(fileToFind)
		  		render "automation/#{@userFound.uuid}"
		  	end
		  end
		else
			@loadedLink = 'admin'
		end
	end

	def list
		if current_user&.present?
			customerToUpdate = Stripe::Customer.retrieve(current_user&.stripeCustomerID)
			@tracking = (customerToUpdate['metadata']['tracking'].present? ? customerToUpdate['metadata']['tracking'].split(',').uniq : []).reject(&:blank?)
			@profileMetadata = customerToUpdate['metadata']
			
		end
		
		if params[:remove] == 'true'
			@newMeta = (@profileMetadata['tracking'].split(',') - [params[:id]]).reject(&:blank?).join(",")
			customerUpdated = Stripe::Customer.update(current_user.stripeCustomerID,{
				metadata: {
					tracking: @newMeta.nil? ? "," : @newMeta.blank? ? "," : @newMeta
				}
			})
			
			flash[:success] = 'Removed From Your Public List'
			redirect_to request.referrer
		elsif params[:id].present?
			
			customerUpdated = Stripe::Customer.update(current_user&.stripeCustomerID,{
				metadata: {
					tracking: customerToUpdate['metadata']['tracking'].present? ? (customerToUpdate['metadata']['tracking']+"#{params[:id]}-#{params[:country]},") : "#{params[:id]}-#{params[:country]},"
				}
			})
			flash[:success] = 'Added To Your Public List'
			redirect_to request.referrer
		end
	end
	
	def loved
		if current_user&.present?
			customerToUpdate = Stripe::Customer.retrieve(current_user.stripeCustomerID)
			@wishlist = (customerToUpdate['metadata']['wishlist'].present? ? customerToUpdate['metadata']['wishlist'].split(',').uniq : []).reject(&:blank?)
			@profileMetadata = customerToUpdate['metadata']
			
		end
		
		if params[:remove] == 'true'
			@newMeta = (@profileMetadata['wishlist'].split(',') - [params[:id]]).reject(&:blank?).join(",")
			customerUpdated = Stripe::Customer.update(current_user&.stripeCustomerID,{
				metadata: {
					wishlist: @newMeta.nil? ? "," : @newMeta.blank? ? "," : @newMeta
				}
			})
			
			flash[:success] = 'Removed From Your Wishlist'
			redirect_to request.referrer
		elsif params[:id].present?
			
			customerUpdated = Stripe::Customer.update(current_user.stripeCustomerID,{
				metadata: {
					wishlist: customerToUpdate['metadata']['wishlist'].present? ? (customerToUpdate['metadata']['wishlist']+"#{params[:id]}-#{params[:country]},") : "#{params[:id]}-#{params[:country]},"
				}
			})
			#analytics
			ahoy.track "Added To Wishlist", product: params[:id]
			flash[:success] = 'Added To Your Wishlist'
			redirect_to request.referrer
		end
	end

	def how_it_works
		
	end
end
















