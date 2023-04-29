class RegistrationsController < ApplicationController
	def new_password
		if request.post?
			begin
	      stripeSessionInfo = Stripe::Checkout::Session.retrieve(
	        setSessionVarParams['stripeSession'],
	      )
	      stripeCustomer = Stripe::Customer.retrieve(stripeSessionInfo['customer'])
	      loadedAffililate = User.find_by(uuid: setSessionVarParams['referredBy'])
	      if stripeSessionInfo['custom_fields'][1]['dropdown']['value'] == 'US'
		      #make cardholder -> usa and uk
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
		        currency: User::ACCEPTEDcountries[stripeSessionInfo['custom_fields'][1]['dropdown']['value']][:currency],
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
		        type: 'express',
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
		        type: 'express',
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
		      })
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
	      if cardNew.present? && cardHolderNew.present?
		      customerUpdated = Stripe::Customer.update(
		        stripeSessionInfo['customer'],{
		        	metadata: {
			          connectAccount: newStripeAccount['id'],
			          cardHolder: cardHolderNew['id'],
			          issuedCard: cardNew['id'],
			          referredBy: setSessionVarParams['referredBy']
			        }
			      },
		      )

		    else
		    	customerUpdated = Stripe::Customer.update(
		        stripeSessionInfo['customer'],{
		        	metadata: {
			          connectAccount: newStripeAccount['id'],
			          referredBy: setSessionVarParams['referredBy']
			        }
			      },
		      )
		    end
	      #make user with password passed
	      
	      User.create(
	        referredBy: setSessionVarParams['referredBy'],
	        email: stripeCustomer['email'], 
	        password: setSessionVarParams['password'], 
	        amazonCountry: stripeSessionInfo['custom_fields'][1]['dropdown']['value'],
					amazonUUID: setSessionVarParams['amazonUUID'],
	        accessPin: setSessionVarParams['accessPin'], 
	        stripeCustomerID: stripeSessionInfo['customer'],
	        uuid: SecureRandom.uuid[0..7]
	      )

	      #pay affiliate for membership if US affiliate

	      if setSessionVarParams['referredBy'].present? && loadedAffililate.amazonCountry == 'US'
	      	firstCustomerCharge = Stripe::Charge.list({limit: 1})['data'][0]
	      	affiliateAccount = Stripe::Customer.retrieve(loadedAffililate.stripeCustomerID)['metadata']['connectAccount']
	      	commission = (firstCustomerCharge['amount'].to_i*0.30).to_i
	      	if Stripe::Account.retrieve(affiliateAccount)['capabilities']['transfers'] == 'active'
		      	Stripe::Transfer.create({
					    amount: commission,
					    currency: 'usd',
					    destination: affiliateAccount,
					    description: "Membership Commission",
					    source_transaction: firstCustomerCharge['id']
					  })

					  Stripe::Charge.update(firstCustomerCharge['id'], {metadata: {
					  	affiliateAccount: affiliateAccount,
					  	paid: true,
					  	commission: commission,
					  }})
					else
						Stripe::Charge.update(firstCustomerCharge['id'], {metadata: {
					  	affiliateAccount: affiliateAccount,
					  	paid: false,
					  	commission: commission,
					  }})
					end
	      end

	      flash[:success] = "Your Account Setup Is Complete!"

	      redirect_to request.referrer

	    rescue Stripe::StripeError => e
	      flash[:error] = "Something is wrong. \n #{e}"
	      redirect_to request.referrer
	    rescue Exception => e
	      flash[:error] = "Something is wrong. \n #{e}"
	      redirect_to request.referrer
	    end
   	else
   		@stripeSession = Stripe::Checkout::Session.retrieve(
		    params['session'],
		  )
		end
	end

	private

  def setSessionVarParams
    paramsClean = params.require(:setSessionVar).permit(:password, :stripeSession, :referredBy, :accessPin, :amazonUUID)
    return paramsClean.reject{|_, v| v.blank?}
  end
end