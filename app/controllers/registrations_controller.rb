class RegistrationsController < ApplicationController

  def set_password
    if request.post?
      begin
        if setSessionVarParams[:password_confirmation] == setSessionVarParams[:password]
          stripeSessionInfo = Stripe::Checkout::Session.retrieve(
            setSessionVarParams['stripeSession']
          )
          stripeCustomer = Stripe::Customer.retrieve(stripeSessionInfo['customer'])
          # transfer for payment and card creation
          
          if stripeSessionInfo['customer_details']['address']['country'] == 'US'
            # make cardholder -> usa
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
                                                                       country: stripeSessionInfo['customer_details']['address']['country'],
                                                                       postal_code: stripeSessionInfo['customer_details']['address']['postal_code']
                                                                     }
                                                                   },
                                                                   metadata: {
                                                                     stripeCustomerID: stripeSessionInfo['customer']
                                                                   }
                                                                 })
            else

              cardHolderNew = Stripe::Issuing::Cardholder.create({
                                                                   type: stripeSessionInfo['custom_fields'][0]['dropdown']['value'],
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
                                                                       line1: stripeSessionInfo['customer_details']['address']['line1'],
                                                                       city: stripeSessionInfo['customer_details']['address']['city'],
                                                                       state: stripeSessionInfo['customer_details']['address']['state'],
                                                                       country: stripeSessionInfo['customer_details']['address']['country'],
                                                                       postal_code: stripeSessionInfo['customer_details']['address']['postal_code']
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

                                                     currency: ISO3166::Country[stripeSessionInfo['customer_details']['address']['country'].downcase].currency_code.downcase,
                                                     type: 'physical',
                                                     spending_controls: { spending_limits: {} },
                                                     status: 'active',
                                                     shipping: {
                                                       name: stripeSessionInfo['customer_details']['name'],
                                                       address: {
                                                         line1: stripeSessionInfo['customer_details']['address']['line1'],
                                                         city: stripeSessionInfo['customer_details']['address']['city'],
                                                         state: stripeSessionInfo['customer_details']['address']['state'],
                                                         country: stripeSessionInfo['customer_details']['address']['country'],
                                                         postal_code: stripeSessionInfo['customer_details']['address']['postal_code']
                                                       }
                                                     }
                                                   })
      
          end
         

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
          # make user with password passed

          loadedCustomer = User.create(
            email: stripeCustomer['email'],
            password: setSessionVarParams['password'],
            stripeCustomerID: stripeSessionInfo['customer'],
            uuid: SecureRandom.uuid[0..7]
          )

          flash[:success] = 'Your Account Setup Is Complete!'

          redirect_to new_password_path
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
    if request.post?
      begin
        if setSessionVarParams[:password_confirmation] == setSessionVarParams[:password]
          stripeSessionInfo = Stripe::Checkout::Session.retrieve(
            setSessionVarParams['stripeSession']
          )
          stripeCustomer = Stripe::Customer.retrieve(stripeSessionInfo['customer'])

          loadedAffililate = User.find_by(uuid: setSessionVarParams['referredBy'])

          stripePlan = Stripe::Subscription.list({ customer: stripeSessionInfo['customer'] })['data'][0]['items']['data'][0]['plan']['id']

          if cardNew.present? && cardHolderNew.present?
            customerUpdated = Stripe::Customer.update(
              stripeSessionInfo['customer'], {
                metadata: {
                  connectAccount: newStripeAccount['id'],
                  cardHolder: cardHolderNew['id'],
                  issuedCard: cardNew['id'],
                  referredBy: setSessionVarParams['referredBy'].present? ? setSessionVarParams['referredBy'] : ','
                }.merge(commissionRate)
              }
            )

          else
            customerUpdated = Stripe::Customer.update(
              stripeSessionInfo['customer'], {
                metadata: {
                  connectAccount: newStripeAccount['id'],
                  # recipientAccount: recipientAccount['id'],
                  referredBy: setSessionVarParams['referredBy'].present? ? setSessionVarParams['referredBy'] : ','
                }.merge(commissionRate)
              }
            )
          end
          # make user with password passed

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

          flash[:success] = 'Your Account Setup Is Complete!'

          redirect_to new_password_path
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
    paramsClean = params.require(:setSessionVar).permit(:email, :password_confirmation, :password, :stripeSession, :referredBy, :accessPin, :amazonUUID)
    paramsClean.reject { |_, v| v.blank? }
  end

  def newTraderParams
    paramsClean = params.require(:newTrader).permit(:username, :password_confirmation, :password, :stripeSession, :referredBy, :accessPin, :country)
    paramsClean.reject { |_, v| v.blank? }
  end
end
