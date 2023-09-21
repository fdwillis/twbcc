class RegistrationsController < ApplicationController

  def new_membership_card
    if request.get?
      @session = Stripe::Checkout::Session.retrieve(params['session'])
    else
      stripeSessionInfo = Stripe::Checkout::Session.retrieve(
        setSessionVarParams['stripeSession']
      )
      stripeCustomer = Stripe::Customer.retrieve(stripeSessionInfo['customer'])
      unless stripeCustomer['metadata']['cardHolder'].present?
        
        if setSessionVarParams['cardType'] == 'company'
          # company
          cardHolderNew = Stripe::Issuing::Cardholder.create({
                                                               type: setSessionVarParams['cardType'],
                                                               name: setSessionVarParams['name'],
                                                               email: stripeSessionInfo['customer_details']['email'],
                                                               phone_number: stripeSessionInfo['customer_details']['phone'],
                                                               billing: {
                                                                 address: {
                                                                   line1: stripeSessionInfo['shipping']['address']['line1'],
                                                                   city: stripeSessionInfo['shipping']['address']['city'],
                                                                   state: stripeSessionInfo['shipping']['address']['state'],
                                                                   country: stripeSessionInfo['shipping']['address']['country'],
                                                                   postal_code: stripeSessionInfo['shipping']['address']['postal_code']
                                                                 }
                                                               },
                                                               metadata: {
                                                                 stripeCustomerID: stripeSessionInfo['customer']
                                                               }
                                                             })
        else
          # individual
          cardHolderNew = Stripe::Issuing::Cardholder.create({
               type: setSessionVarParams['cardType'],
               email: stripeSessionInfo['customer_details']['email'],
               name: "#{setSessionVarParams['first_name']} #{setSessionVarParams['last_name']}",
               individual: { 
               first_name: setSessionVarParams['first_name'],
               last_name: setSessionVarParams['last_name'],
                dob: {
                  day: setSessionVarParams['dob'].split('-')[2].to_i,
                  month:setSessionVarParams['dob'].split('-')[1].to_i,
                  year: setSessionVarParams['dob'].split('-')[0].to_i
                },
                card_issuing: { 
                  user_terms_acceptance: { 
                    date: Time.now.to_i,
                    ip: Socket.ip_address_list.first.ip_address 
                  }
                } 
              },
               phone_number: stripeSessionInfo['customer_details']['phone'],
               billing: {
                 address: {
                   line1: stripeSessionInfo['shipping']['address']['line1'],
                   city: stripeSessionInfo['shipping']['address']['city'],
                   state: stripeSessionInfo['shipping']['address']['state'],
                   country: stripeSessionInfo['shipping']['address']['country'],
                   postal_code: stripeSessionInfo['shipping']['address']['postal_code']
                 }
               },
               metadata: {
                 stripeCustomerID: stripeSessionInfo['customer']
               }
          })
        end
        # make card only in usa and uk currently

        cardNew = Stripe::Issuing::Card.create({
         cardholder: cardHolderNew['id'],

         currency: ISO3166::Country[stripeSessionInfo['shipping']['address']['country'].downcase].currency_code.downcase,
         type: 'physical',
         spending_controls: { spending_limits: {} },
         status: 'active',
         shipping: {
           name: setSessionVarParams['cardType'] == 'company' ? setSessionVarParams['name'] : "#{setSessionVarParams['first_name']} #{setSessionVarParams['last_name']}",
           address: {
             line1: stripeSessionInfo['shipping']['address']['line1'],
             city: stripeSessionInfo['shipping']['address']['city'],
             state: stripeSessionInfo['shipping']['address']['state'],
             country: stripeSessionInfo['shipping']['address']['country'],
             postal_code: stripeSessionInfo['shipping']['address']['postal_code']
           }
           }
        })
    
       

        if cardNew.present? && cardHolderNew.present?
          customerUpdated = Stripe::Customer.update(
            stripeSessionInfo['customer'], {
              metadata: {
                cardHolder: cardHolderNew['id'],
                issuedCard: cardNew['id'],
              }
            }
          )

        end
        
        

      end
      flash[:success] = 'Your Card Is On The Way'
      redirect_to "/new-password-set?session=#{setSessionVarParams['stripeSession']}"
    end


    
    
  end

  def set_password
    if request.post?
      begin
        if setSessionVarParams[:password_confirmation] == setSessionVarParams[:password]
          stripeSessionInfo = Stripe::Checkout::Session.retrieve(
            setSessionVarParams['stripeSession']
          )
          stripeCustomer = Stripe::Customer.retrieve(stripeSessionInfo['customer'])
          # transfer for payment and card creation
          
          # make cardholder -> usa
          

          # make user with password passed

          loadedCustomer = User.create(
            email: stripeCustomer['email'],
            password: setSessionVarParams['password'],
            stripeCustomerID: stripeSessionInfo['customer'],
            uuid: SecureRandom.uuid[0..7]
          )
          #make transfer for subscription at 2%
          
          transferX = Stripe::Transfer.create({
                                      amount: (stripeSessionInfo['amount_total'] * 0.02).to_i,
                                      currency: 'usd',
                                      destination: ENV['oarlinStripeAccount'],
                                      description: 'Membership',
                                      source_transaction: Stripe::Invoice.retrieve(stripeSessionInfo['invoice'])['charge']
                                    })
          
          


          flash[:success] = 'Your Account Setup Is Complete!'

          if stripeSessionInfo['custom_fields'][0]['dropdown']['value'] == 'yes'
            successURL = "https://card.twbcc.com/new-membership-card?session={CHECKOUT_SESSION_ID}"

            @basicSession = Stripe::Checkout::Session.create({
              success_url: successURL,
              phone_number_collection: {
               enabled: true
              },
              shipping_address_collection: {
                allowed_countries: ['US']
              },
              customer: stripeSessionInfo['customer'],
              line_items: [
               { price: 'price_1NiJRWHvKdEDURjLEOuvHIKM', quantity: 1 }
              ],
              mode: 'payment'
            })

            redirect_to @basicSession['url']
          else
            redirect_to "/new-password-set?session=#{setSessionVarParams['stripeSession']}"
          end
        else
          flash[:alert] = 'Password Must Match'
          redirect_to request.referrer
          nil
        end
      rescue Stripe::StripeError => e
        flash[:error] = e.error.message.to_s
        redirect_to request.referrer
      rescue Exception => e
        flash[:error] = e.to_s
        redirect_to request.referrer
      end
    else
      @stripeSession = Stripe::Checkout::Session.retrieve(
        params['session']
      )
    end
  end

  def new
    if request.get?
    else
      createdUser = User.create(setSessionVarParams)
      if createdUser.present?
        flash[:success] = 'Sign Up Complete'
        redirect_to request.referrer
        return
      else
        flash[:error] = "Something Went Wrong"
        redirect_to request.referrer
        return
      end
    end
  end

  def new_password
    @stripeSession = Stripe::Checkout::Session.retrieve(
      params['session']
    )

    paymentIntent = @stripeSession['payment_intent']
    
    if Stripe::PaymentIntent.retrieve(paymentIntent)['metadata']['transfered'] != true
      balanceTransaction = Stripe::PaymentIntent.retrieve(paymentIntent)['charges']['data'][0]['balance_transaction']

      transferX = Stripe::Transfer.create({
                                amount: Stripe::BalanceTransaction.retrieve(balanceTransaction)['net'] - 350,
                                currency: 'usd',
                                destination: ENV['oarlinStripeAccount'],
                                description: 'Card Printed',
                                source_transaction: Stripe::PaymentIntent.retrieve(paymentIntent)['charges']['data'][0]['id']
                              })
      updateIntent = Stripe::PaymentIntent.update(paymentIntent,{metadata: {transfered: true}})
    end
  end

  def trading
    # route here after successful checkout of price
    # email them their sessionLink via webhook sessionLinkEmail

    if request.post?
      begin
        if newTraderParams[:password_confirmation] == newTraderParams[:password]
          stripeSessionInfo = Stripe::Checkout::Session.retrieve(
            newTraderParams['stripeSession']
          )
          stripeCustomer = Stripe::Customer.retrieve(stripeSessionInfo['customer'])

          stripePlan = Stripe::Subscription.list({ customer: stripeSessionInfo['customer'] })['data'][0]['items']['data'][0]['plan']['id']

          newStripeAccount = Stripe::Account.create({
                                                      type: 'standard',
                                                      country: stripeSessionInfo['customer_details']['address']['country'],
                                                      email: stripeCustomer['email']
                                                    })

          customerUpdated = Stripe::Customer.update(
            stripeSessionInfo['customer'], {
              metadata: {
                referredBy: newTraderParams['referredBy'].present? ? newTraderParams['referredBy'] : ',',
                commissionRate: 10,
                connectAccount: newStripeAccount['id']
              }
            }
          )
          # make user with password passed
          loadedCustomer = User.create(
            referredBy: newTraderParams['referredBy'].present? ? newTraderParams['referredBy'] : ',',
            email: stripeCustomer['email'],
            username: newTraderParams['username'],
            password: newTraderParams['password'],
            accessPin: newTraderParams['accessPin'],
            stripeCustomerID: stripeSessionInfo['customer'],
            uuid: SecureRandom.uuid[0..7],
            amazonCountry: stripeSessionInfo['customer_details']['address']['country']
          )

          loadedCustomer.checkMembership
          if loadedCustomer.trial?
            loadedCustomer.update(authorizedList: stripeSessionInfo['custom_fields'][0]['dropdown']['value'])
          end

          flash[:success] = 'Your Account Is Setup!'
          redirect_to request.referrer
          nil
        else
          flash[:alert] = 'Password Must Match'
          redirect_to request.referrer
          nil
        end
      rescue Stripe::StripeError => e
        flash[:error] = e.error.message.to_s
        redirect_to request.referrer
      rescue Exception => e
        flash[:error] = e.to_s
        redirect_to request.referrer
      end
    else
      @stripeSession = Stripe::Checkout::Session.retrieve(
        params['session']
      )
    end
  end

  def trial; end

  private

  def setSessionVarParams
    paramsClean = params.require(:setSessionVar).permit(:cardType, :name, :first_name, :last_name, :dob, :email, :password_confirmation, :password, :stripeSession, :referredBy, :accessPin, :amazonUUID)
    paramsClean.reject { |_, v| v.blank? }
  end

  def newTraderParams
    paramsClean = params.require(:newTrader).permit(:username, :password_confirmation, :password, :stripeSession, :referredBy, :accessPin, :country)
    paramsClean.reject { |_, v| v.blank? }
  end
end
