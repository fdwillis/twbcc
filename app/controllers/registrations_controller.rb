class RegistrationsController < ApplicationController
	def new_password
		if request.post?
			begin
				if setSessionVarParams[:password_confirmation] == setSessionVarParams[:password]
		      stripeSessionInfo = Stripe::Checkout::Session.retrieve(
		        setSessionVarParams['stripeSession'],
		      )
		      stripeCustomer = Stripe::Customer.retrieve(stripeSessionInfo['customer'])

		      
		      loadedAffililate = User.find_by(uuid: setSessionVarParams['referredBy'])

		      stripePlan = Stripe::Subscription.list({customer: stripeSessionInfo['customer']})['data'][0]['items']['data'][0]['plan']['id']
		      
		      if stripeSessionInfo['custom_fields'][1]['dropdown']['value'] == 'US'
			      #make cardholder -> usa
			      if stripeSessionInfo['custom_fields'][0]['dropdown']['value'] == 'company'
			        cardHolderNew = Stripe::Issuing::Cardholder.create({
			          type: stripeSessionInfo['custom_fields'][0]['dropdown']['value'],
			          name: stripeSessionInfo['customer_details']['name'],
			          email: stripeSessionInfo['customer_details']['email'],
			          phone_number: stripeSessionInfo['customer_details']['phone'],
			          billing: {
			            address: {
			              line1: stripeSessionInfo['customer_details']['address']['line1'],
			              city: stripeSessionInfo['customer_details']['address']['city'],
			              state: stripeSessionInfo['customer_details']['address']['state'],
			              country: stripeSessionInfo['custom_fields'][1]['dropdown']['value'],
			              postal_code: stripeSessionInfo['customer_details']['address']['postal_code'],
			            },
			          },
			          metadata: {
			            stripeCustomerID: stripeSessionInfo['customer']
			          },
			        })
			      else
			        cardHolderNew = Stripe::Issuing::Cardholder.create({
			          type: stripeSessionInfo['custom_fields'][0]['dropdown']['value'],
			          name: stripeSessionInfo['customer_details']['name'],
			          email: stripeSessionInfo['customer_details']['email'],
			          individual: {card_issuing: 
			            {user_terms_acceptance: {date: Time.now.to_i, ip: Socket.ip_address_list.first.ip_address}}
			          },
			          phone_number: stripeSessionInfo['customer_details']['phone'],
			          billing: {
			            address: {
			              line1: stripeSessionInfo['customer_details']['address']['line1'],
			              city: stripeSessionInfo['customer_details']['address']['city'],
			              state: stripeSessionInfo['customer_details']['address']['state'],
			              country: stripeSessionInfo['custom_fields'][1]['dropdown']['value'],
			              postal_code: stripeSessionInfo['customer_details']['address']['postal_code'],
			            },
			          },
			          metadata: {
			            stripeCustomerID: stripeSessionInfo['customer']
			          },
			        })
			      end
			      #make card only in usa and uk currently
			      cardNew = Stripe::Issuing::Card.create({
			        cardholder: cardHolderNew['id'],
			        currency: User::ACCEPTEDcountries[stripeSessionInfo['custom_fields'][1]['dropdown']['value'].downcase][:currency],
			        type: 'physical',
			        spending_controls: {spending_limits: {}},
			        status: 'active',
			        shipping: {
			          name: stripeSessionInfo['customer_details']['name'],
			          address: {
			            line1: stripeSessionInfo['customer_details']['address']['line1'],
			            city: stripeSessionInfo['customer_details']['address']['city'],
			            state: stripeSessionInfo['customer_details']['address']['state'],
			            country: stripeSessionInfo['custom_fields'][1]['dropdown']['value'],
			            postal_code: stripeSessionInfo['customer_details']['address']['postal_code'],
			          }}
			      })
		      end
		      #make connect account
		      if stripeSessionInfo['custom_fields'][1]['dropdown']['value'] == 'US'
			      newStripeAccount = Stripe::Account.create({
			        type: 'standard',
			        country: stripeSessionInfo['custom_fields'][1]['dropdown']['value'],
			        email: stripeCustomer['email'],
			        capabilities: {
			          card_payments: {requested: true},
			          # card_issuing: {requested: true},
			          # cash_advances: {requested: true},
			          cashapp_payments: {requested: true},
			          # loans: {requested: true},
			          transfers: {requested: true},
			          # treasury: {requested: true},
			          us_bank_account_ach_payments: {requested: true},
			        },
			      })
			    else
			    	newStripeAccount = Stripe::Account.create({
			        type: 'standard',
			        country: stripeSessionInfo['custom_fields'][1]['dropdown']['value'],
			        email: stripeCustomer['email'],
			        capabilities: {
			          card_payments: {requested: true},
			          # card_issuing: {requested: true},
			          # cash_advances: {requested: true},
			          # cashapp_payments: {requested: true},
			          # loans: {requested: true},
			          transfers: {requested: true},
			          # treasury: {requested: true},
			          # us_bank_account_ach_payments: {requested: true},
			        },
			        tos_acceptance: {service_agreement: 'full'},
			      })

			      # recipientAccount = Stripe::Account.create(
						#   {
						#     type: 'custom',
						#     country: stripeSessionInfo['custom_fields'][1]['dropdown']['value'],
						#     email: stripeCustomer['email'],
						#     capabilities: {
						#     	transfers: {requested: true},
						#     },
						#     tos_acceptance: {service_agreement: 'recipient'},
						#   },
						# )
			    end

			      # Stripe::Account.update(newStripeAccount['id'],{
			      #   tos_acceptance: 
			      #     {
			      #       date: Time.now.to_i,
			      #       ip: Socket.ip_address_list.first.ip_address
			      #     },
			      #     settings:{
			      #       payouts:{
			      #         debit_negative_balances: true
			      #       },
			      #       card_issuing: {
			      #         tos_acceptance: {
			      #           date: Time.now.to_i, ip: Socket.ip_address_list.first.ip_address
			      #         }
			      #       },
			      #       treasury: {
			      #         tos_acceptance: {
			      #           date: Time.now.to_i, ip: Socket.ip_address_list.first.ip_address
			      #         }
			      #       }
			      #     }
			      #   }
			      # )

			      #attach details to customer profile and cardholder profile
			      
		      commissionRate = {commissionRate: User::FREEmembership.include?(stripePlan) == true ? 0 : User::AFFILIATEmembership.include?(stripePlan) == true ? 5 : User::BUSINESSmembership.include?(stripePlan) == true ? 10 : User::AUTOMATIONmembership.include?(stripePlan) == true ? 20 : 0}
		      
		      if cardNew.present? && cardHolderNew.present?
			      customerUpdated = Stripe::Customer.update(
			        stripeSessionInfo['customer'],{
			        	metadata: {
				          connectAccount: newStripeAccount['id'],
				          cardHolder: cardHolderNew['id'],
				          issuedCard: cardNew['id'],
				          referredBy: setSessionVarParams['referredBy'].present? ? setSessionVarParams['referredBy'] : ','
				        }.merge(commissionRate)
				      },
			      )

			    else
			    	customerUpdated = Stripe::Customer.update(
			        stripeSessionInfo['customer'],{
			        	metadata: {
				          connectAccount: newStripeAccount['id'],
				          # recipientAccount: recipientAccount['id'],
				          referredBy: setSessionVarParams['referredBy'].present? ? setSessionVarParams['referredBy'] : ','
				        }.merge(commissionRate)
				      },
			      )
			    end
		      #make user with password passed
		      
		      loadedCustomer = User.create(
		        referredBy: setSessionVarParams['referredBy'].present? ? setSessionVarParams['referredBy'] : ',',
		        email: stripeCustomer['email'], 
		        password: setSessionVarParams['password'], 
		        amazonCountry: stripeSessionInfo['custom_fields'][1]['dropdown']['value'],
						amazonUUID: setSessionVarParams['amazonUUID'],
		        accessPin: setSessionVarParams['accessPin'], 
		        stripeCustomerID: stripeSessionInfo['customer'],
		        uuid: SecureRandom.uuid[0..7]
		      )

		      #pay affiliate for membership if US affiliate
		      if setSessionVarParams['referredBy'].present? && !loadedAffililate.checkMembership.map{|d| d[:membershipType]}.include?('free') && loadedAffililate.amazonCountry.upcase == 'US'
		      	firstCustomerCharge = Stripe::Charge.list({limit: 1})['data'][0]
		      	affiliateAccount = Stripe::Customer.retrieve(loadedAffililate.stripeCustomerID)
		      	commission = (firstCustomerCharge['amount'].to_i*(affiliateAccount['metadata']['commissionRate'].to_f/100)).to_i
		      	#analytics
		      	#only pay if affiliate is active on current membership
		      	if Stripe::Account.retrieve(affiliateAccount['metadata']['connectAccount'])['capabilities']['transfers'] == 'active'
			      	Stripe::Transfer.create({
						    amount: commission,
						    currency: 'usd',
						    destination: loadedAffililate.amazonCountry == 'US' ? affiliateAccount['metadata']['connectAccount'] : affiliateAccount['metadata']['recipientAccount'],
						    description: "Membership Commission",
						    source_transaction: firstCustomerCharge['id']
						  })
						end
		      end

		      # btly
		      
		      if !loadedCustomer&.checkMembership.map{|d| d[:membershipType]}.include?('free')
		      	oauth = Bitly::OAuth.new(client_id: ENV['bitlyClient'], client_secret: ENV['bitlySecret'])
						@bitlyToken = oauth.access_token(username: 'team@oarlin.com', password: ENV['bitlyPass'])

						@bitlyClient = Bitly::API::Client.new(
						  token: ENV['bitlyToken']
						)
		      	generateLink = @bitlyClient.shorten(long_url: "https://app.oarlin.com/profile/#{loadedCustomer&.uuid}?&referredBy=#{loadedCustomer&.uuid}")
		      	
		      	generateLink.update(title: "Profile #{loadedCustomer&.uuid}")
		      
		      	Stripe::Customer.update(
			        stripeSessionInfo['customer'],{
			        	metadata: {
				          shortLink: generateLink.link,
				          # recipientAccount: recipientAccount['id'],.map{|d| d[:membershipType]}.include?('trader')
				        }
				      },
			      )
		      end
		      
	      	ahoy.track "Membership Signup", headline: session['howITWOrks'], previousPage: request.referrer, uuid: User.find_by(stripeCustomerID: stripeSessionInfo['customer']).uuid, referredBy: setSessionVarParams['referredBy'].present? ? setSessionVarParams['referredBy'] : 'admin'
		      
		      if session['coupon'].present?
			      ahoy.track "Membership Coupon Applied", coupon: session['coupon'], membershipType: User.find_by(stripeCustomerID: stripeSessionInfo['customer']).checkMembership.map{|d| d[:membershipType]}
		      end

		      flash[:success] = "Your Account Setup Is Complete!"

		      redirect_to new_password_path
		    else
		    	flash[:alert] = 'Password Must Match'
		    	redirect_to request.referrer
		    	return
		    end
	    rescue Stripe::StripeError => e
	      flash[:error] = "#{e.error.message}"
	      redirect_to request.referrer
	    rescue Exception => e
	      flash[:error] = "#{e}"
	      redirect_to request.referrer
	    end
   	else
   		@stripeSession = Stripe::Checkout::Session.retrieve(
		    params['session'],
		  )
		end
	end

	def trading
		#route here after successful checkout of price
		# email them their sessionLink via webhook sessionLinkEmail

		if request.post?
			begin
				if newTraderParams[:password_confirmation] == newTraderParams[:password]
		      stripeSessionInfo = Stripe::Checkout::Session.retrieve(
		        newTraderParams['stripeSession'],
		      )
		      stripeCustomer = Stripe::Customer.retrieve(stripeSessionInfo['customer'])

		      stripePlan = Stripe::Subscription.list({customer: stripeSessionInfo['customer']})['data'][0]['items']['data'][0]['plan']['id']
		      
		      newStripeAccount = Stripe::Account.create({
		        type: 'standard',
		        country: stripeSessionInfo['customer_details']['address']['country'],
		        email: stripeCustomer['email'],
		      })

		    	customerUpdated = Stripe::Customer.update(
		        stripeSessionInfo['customer'],{
		        	metadata: {
			          referredBy: newTraderParams['referredBy'].present? ? newTraderParams['referredBy'] : ',',
			          commissionRate: 0,
			          connectAccount: newStripeAccount['id']
			        }
			      },
		      )
		      #make user with password passed
		      loadedCustomer = User.create(
		        referredBy: newTraderParams['referredBy'].present? ? newTraderParams['referredBy'] : ',',
		        email: stripeCustomer['email'], 
		        password: newTraderParams['password'], 
		        accessPin: newTraderParams['accessPin'], 
		        stripeCustomerID: stripeSessionInfo['customer'],
		        uuid: SecureRandom.uuid[0..7],
		        amazonCountry:  stripeSessionInfo['customer_details']['address']['country'],
		      )

		      loadedCustomer.checkMembership
		      if loadedCustomer.trial?
		      	loadedCustomer.update(authorizedList:  stripeSessionInfo['custom_fields'][0]['dropdown']['value'])
		      end

	      	ahoy.track "Trader Signup", previousPage: request.referrer, uuid: loadedCustomer.uuid, referredBy: newTraderParams['referredBy'].present? ? newTraderParams['referredBy'] : 'admin'

		      flash[:success] = "Your Account Is Setup!"
		      redirect_to request.referrer
		      return
		    else
		    	flash[:alert] = 'Password Must Match'
		    	redirect_to request.referrer
		    	return
		    end
	    rescue Stripe::StripeError => e
	      flash[:error] = "#{e.error.message}"
	      redirect_to request.referrer
	    rescue Exception => e
	      flash[:error] = "#{e}"
	      redirect_to request.referrer
	    end
		else
   		@stripeSession = Stripe::Checkout::Session.retrieve(
		    params['session'],
		  )
   	end
	end

	def trial
		
	end

	private

  def setSessionVarParams
    paramsClean = params.require(:setSessionVar).permit(:password_confirmation, :password, :stripeSession, :referredBy, :accessPin, :amazonUUID)
    return paramsClean.reject{|_, v| v.blank?}
  end

  def newTraderParams
    paramsClean = params.require(:newTrader).permit(:password_confirmation, :password, :stripeSession, :referredBy, :accessPin, :country)
    return paramsClean.reject{|_, v| v.blank?}
  end
end


