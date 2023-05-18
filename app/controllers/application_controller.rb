class ApplicationController < ActionController::Base
	before_action :authenticate_user!, only: [:loved, :list] 
	before_action :loadMemberships
	
	def update_discount
		begin
			membershipDetails = current_user&.checkMembership
			if membershipDetails[:membershipDetails][0]['status'] == 'active'
				subscriptions = Stripe::Subscription.list({limit: 100, customer: current_user&.stripeCustomerID})
				subscriptions.each do |subs|
					Stripe::Subscription.update(
					  subs['id'],
					  {coupon: session['coupon']},
					)
				end
				flash[:success] = "Coupon Claimed"
		    redirect_to profile_path
			else
				flash[:error] = "Please Update Your Membership Before Using This Feature"
		    redirect_to membership_path
			end
		rescue Stripe::StripeError => e
      flash[:error] = "#{e.error.message}"
      redirect_to request.referrer
    rescue Exception => e
      flash[:error] = "#{e}"
      redirect_to request.referrer
    end
	end

	def discounts #sprint2
		if session['coupon'].nil? 
			@discountsFor = current_user.present? ? current_user&.checkMembership : nil
			@discountList = Stripe::Coupon.list({limit: 100})['data'].reject{|c| c['valid'] == false}
			if @discountsFor.nil? || @discountsFor[:membershipType] == 'free'
				@newList = @discountList.reject{|c| c['percent_off'] > 10}.reject{|c| c['percent_off'] > 90}.size > 0 ? @discountList.reject{|c| c['percent_off'] > 10}.reject{|c| c['percent_off'] > 90}.sample['id'] : 0
			elsif @discountsFor[:membershipType] == 'affiliate'
				@newList = @discountList.reject{|c| c['percent_off'] > 20 || c['percent_off'] < 10}.reject{|c| c['percent_off'] > 90}.size > 0 ? @discountList.reject{|c| c['percent_off'] > 20 || c['percent_off'] < 10}.reject{|c| c['percent_off'] > 90}.sample['id'] : 0
			elsif @discountsFor[:membershipType] == 'business'
				@newList = @discountList.reject{|c| c['percent_off'] > 30 || c['percent_off'] < 20}.reject{|c| c['percent_off'] > 90}.size > 0 ? @discountList.reject{|c| c['percent_off'] > 30 || c['percent_off'] < 20}.reject{|c| c['percent_off'] > 90}.sample['id'] : 0
			elsif @discountsFor[:membershipType] == 'automation'
				@newList = @discountList.reject{|c| c['percent_off'] > 40 || c['percent_off'] < 30}.reject{|c| c['percent_off'] > 90}.size > 0 ? @discountList.reject{|c| c['percent_off'] > 40 || c['percent_off'] < 30}.reject{|c| c['percent_off'] > 90}.sample['id'] : 0
			elsif @discountsFor[:membershipType] == 'custom'
				@newList = @discountList.reject{|c| c['percent_off'] > 50 || c['percent_off'] < 40}.reject{|c| c['percent_off'] > 90}.size > 0 ? @discountList.reject{|c| c['percent_off'] > 50 || c['percent_off'] < 40}.reject{|c| c['percent_off'] > 90}.sample['id'] : 0
			end

			session['coupon'] = @newList 
		else
			if Stripe::Coupon.list({limit: 100}).map(&:id).include?(session['coupon']) == true
				@newList = session['coupon']
			else
				session['coupon'] = nil
				@newList = session['coupon']
			end
		end
	end

	def display_discount
		# setcoupon code in header
		if session['coupon'].nil?
			codes = Stripe::Coupon.list({limit: 100})['data'].reject{|c| c['percent_off'] > 10 || c['valid'] == false}.reject{|c| c['percent_off'] > 90}
			if codes.size > 0
				session['coupon'] = codes.sample['id']
				flash[:success] = "Coupon Assigned"
				ahoy.track "Coupon Clicked", previousPage: request.referrer, coupon: session['coupon']
				redirect_to request.referrer
				return
			else
				flash[:notice] = "Waiting For New Coupons"
				redirect_to discounts_path
				return
			end
		end
	end

	def split_session
		ahoy.track "Split Session", uuid: @userFound.uuid, previousPage: request.referrer
		redirect_to "#{request.fullpath.split("?")[0]}?&referredBy=#{params[:splitSession]}"
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
		begin
				affiliateFromId = User.find_by(uuid: params[:id])
				@pulledAffiliate = Stripe::Customer.retrieve(affiliateFromId&.stripeCustomerID)
				@pulledCommissions = Stripe::Customer.list(limit: 100)
				@accountsFromAffiliate = @pulledCommissions['data'].reject{|e| e['metadata']['referredBy'] != params[:id]}
				@activeSubs = []
				@inactiveSubs = []
				@accountItemsDue = Stripe::Account.retrieve(Stripe::Customer.retrieve(affiliateFromId&.stripeCustomerID)['metadata']['connectAccount'])['requirements']['currently_due']
				@accountsFromAffiliate.each do |cusID|
			  	listofSubscriptionsFromCusID = Stripe::Subscription.list(limit: 100, customer: cusID)['data']
			    if listofSubscriptionsFromCusID.size > 0 
				  	listofSubscriptionsFromCusID.each do |subscriptionX| 
					  	if subscriptionX['status'] == 'active' 
					  		@activeSubs << subscriptionX
					  	else
					  		@inactiveSubs << subscriptionX
					  	end
				  	end
			  	end
				end
				@combinedCommissions = 0
				@monthlyCommissions = 0
				@annualCommissions = 0

				@activeSubs.map(&:items).map(&:data).flatten.map(&:plan).each do |plan|
					if plan['interval'] == 'month'
						@combinedCommissions += (plan['amount'] * 12) * (@pulledAffiliate['metadata']['commissionRate'].to_i * 0.01)
						@monthlyCommissions += 1
					end

					if plan['interval'] == 'year'
						
						@combinedCommissions += (plan['amount']) * (@pulledAffiliate['metadata']['commissionRate'].to_i * 0.01)
						@annualCommissions += 1
					end
				end

				@combinedCommissions

				@payouts = Stripe::Payout.list({limit: 3},{stripe_account: @pulledAffiliate['metadata']['connectAccount']})['data']
		rescue Stripe::StripeError => e
      flash[:error] = "#{e.error.message}"
      redirect_to request.referrer
    rescue Exception => e
      flash[:error] = "#{e}"
      redirect_to request.referrer
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
		@codes = Stripe::Coupon.list({limit: 100}).reject{|c| c['valid'] == false}

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
		
		if session['coupon'].nil?	
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
		else
			if @codes.map(&:id).include?(session['coupon']) == true && Stripe::Coupon.retrieve(session['coupon']).valid == true
				# free -> build on page, 
				# affiliate, 
				@freeMembership = Stripe::Checkout::Session.create({
		      success_url: successURL,
		      custom_fields: customFields,
		      phone_number_collection: {
			      enabled: true
			    },
				  discounts: [
				  	coupon: session['coupon']
				  ],
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
				  discounts: [
				  	coupon: session['coupon']
				  ],
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
				  discounts: [
				  	coupon: session['coupon']
				  ],
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
				  discounts: [
				  	coupon: session['coupon']
				  ],
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
				  discounts: [
				  	coupon: session['coupon']
				  ],
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
				  discounts: [
				  	coupon: session['coupon']
				  ],
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
				  discounts: [
				  	coupon: session['coupon']
				  ],
		      shipping_address_collection: {allowed_countries: allowedCountries},
		      line_items: [
		        {price: ENV['automationAnnual'], quantity: 1},
		      ],
		      mode: 'subscription',
		    }) 
				# custom -> build on page, 
			else
				session['coupon'] = nil
				flash[:notice] = "Coupon Expired"
				redirect_to request.referrer
				return
			end
		end
		ahoy.track "Membership Visited", previousPage: request.referrer
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
			
			# 	@recipientAccountUpdate = Stripe::AccountLink.create(
			# 	  {
			# 	    account: Stripe::Customer.retrieve(current_user.stripeCustomerID)['metadata']['connectAccount'],
			# 	    refresh_url: "http://#{request.env['HTTP_HOST']}",
			# 	    return_url: "http://#{request.env['HTTP_HOST']}",
			# 	    type: 'account_onboarding',
			# 	  },
			# 	)

			# 	@recipientAccountItemsDue = Stripe::Account.retrieve(Stripe::Customer.retrieve(current_user.stripeCustomerID)['metadata']['recipientAccount'])['requirements']['currently_due']
		else
			#analytics
			ahoy.track "Profile Visit", uuid: @userFound.uuid, previousPage: request.referrer
		end
		
		if @membershipDetails.present? && @membershipDetails[:membershipDetails][0]['status']	== 'active'
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
			ahoy.track "Added To Loved List", asin: params[:id], uuid: current_user&.uuid, previousPage: request.referrer
		end
		
		if params[:remove] == 'true'
			@newMeta = (@profileMetadata['wishlist'].split(',') - [params[:id]]).reject(&:blank?).join(",")
			customerUpdated = Stripe::Customer.update(current_user&.stripeCustomerID,{
				metadata: {
					wishlist: @newMeta.nil? ? "," : @newMeta.blank? ? "," : @newMeta
				}
			})
			
			flash[:success] = 'Removed From Your Love List'
			redirect_to request.referrer
		elsif params[:id].present?
			
			customerUpdated = Stripe::Customer.update(current_user.stripeCustomerID,{
				metadata: {
					wishlist: customerToUpdate['metadata']['wishlist'].present? ? (customerToUpdate['metadata']['wishlist']+"#{params[:id]}-#{params[:country]},") : "#{params[:id]}-#{params[:country]},"
				}
			})
			#analytics
			flash[:success] = 'Added To Your Loved List'
			redirect_to request.referrer
		end
	end

	def how_it_works
		if session['howITWOrks'].present?
		else
			@headlines = ['Signup - Share - Earn','Made Exclusively For Amazon Associates','Customizable Automation For Amazon Associates','Oarlin - Join The Hive','Supercharged Automation For Amazon Associates']

			session['howITWOrks'] = @headlines.sample
		end
		ahoy.track "How It Works Visited", previousPage: request.referrer, title: session['howITWOrks']
	end

	def loadMemberships
		
	end
end
















