class ApplicationController < ActionController::Base
  before_action :authenticate_user!, only: %i[your_membership transactions pause_membership manage_discounts edit_discounts]

  def business_directory
    @couponsOffer = []
    @connectAccounts = Stripe::Account.list({limit: 100})['data']
    @connectAccounts.each do |connX|
      if Stripe::Coupon.list({ limit: 100 }, {stripe_account: connX['id'] }).present?
        @couponsOffer << connX
      end
    end
  end

  def claim_discount
    if current_user

      stripeAccountX = Stripe::Account.retrieve(params['account'])
      unless session[params['account'].to_sym].present?
        couponList = Stripe::Coupon.list({},{stripe_account: params['account']})['data']
        session[params['account'].to_sym] = couponList.sample['id']
      end
      #set in session and edit meta
      flash[:success] = "Coupon Applied"
      redirect_to request.referrer
    else
      flash[:notice] = "Discounts available for members only"
      redirect_to memberships_path
    end
  end

  def edit_discounts
    @stripeAccountID = Stripe::Customer.retrieve(current_user&.stripeCustomerID)['metadata']['connectAccount']
    @stripeAccount = Stripe::Account.retrieve(@stripeAccountID)
    
    begin
      if request.post?
        done = Stripe::Account.update(@stripeAccountID, {metadata: {maxDiscount: params['editDiscounts']['maxDiscount'], redemptions: params['editDiscounts']['redemptions'], refreshRate: params['editDiscounts']['refreshRate']}})
        flash[:success] = "Settings Changed"
        redirect_to manage_discounts_path
        return
      end
    rescue Stripe::StripeError => e
      session['coupon'] = nil
      flash[:error] = e.error.message.to_s
      redirect_to request.referrer
    rescue Exception => e
      session['coupon'] = nil
      flash[:error] = e.to_s
      redirect_to request.referrer
    end
  end

  def manage_discounts
    @stripeCustomerX = Stripe::Customer.retrieve(current_user&.stripeCustomerID)
    unless @stripeCustomerX['metadata']['connectAccount'].present?
      newStripeAccount = Stripe::Account.create({
        type: 'standard',
        country: 'US',
        email: @stripeCustomerX['email']
      })
      customerUpdated = Stripe::Customer.update(
        current_user&.stripeCustomerID, {
          metadata: {
            connectAccount: newStripeAccount['id'],
          }
        }
      )
    end
    @stripeAccountUpdate = Stripe::AccountLink.create(
      {
        account: Stripe::Customer.retrieve(current_user&.stripeCustomerID)['metadata']['connectAccount'],
        refresh_url: "https://card.twbcc.com/manage-discounts",
        return_url: "https://card.twbcc.com/manage-discounts",
        type: 'account_onboarding'
      }
    )

    @accountItemsDue = Stripe::Account.retrieve(Stripe::Customer.retrieve(current_user&.stripeCustomerID)['metadata']['connectAccount'])['requirements']['currently_due']
    
    @codes = Stripe::Coupon.list({limit: 100}, stripe_account: Stripe::Customer.retrieve(current_user&.stripeCustomerID)['metadata']['connectAccount'] )['data']
  end

  def transactions
    builtPayload = []

    @userFound = params['id'].present? ? User.find_by(uuid: params['id']) : current_user
    @profile = @userFound.present? ? Stripe::Customer.retrieve(@userFound&.stripeCustomerID) : nil
    @issuingTransactions = Stripe::Issuing::Authorization.list({card: @profile['metadata']['issuedCard']})['data'].reject{|d| d['approved'] != true}
    @deposits = Stripe::Charge.list({limit: 100, customer: current_user&.stripeCustomerID}).reject{|d| !d['metadata']['topUp'].present?}

    builtPayload << @issuingTransactions.map{|d| {created: DateTime.strptime(d['created'].to_s,'%s'), item: d['merchant_data']['name'], status: d['approved'] == true ? 'Approved' : 'Declined', amount: d['amount'].to_i}}.flatten
    builtPayload << @deposits.map{|d| {created: DateTime.strptime(d['created'].to_s,'%s'), item: 'Deposit', status: 'Approved', amount: d['metadata']['requestAmount'].to_i}}.reject{|d| d[:amount] == 0}.flatten
    transactions = @issuingTransactions.map(&:amount).sum * 0.01
    @balance = @deposits.map{|d| d['metadata']['requestAmount'].to_i}.sum * 0.01 - transactions
    @builtPayload = builtPayload.flatten
  end

  def your_membership
    memberships
    @subscriptionList = []
    @stripeCustomer = Stripe::Customer.retrieve(current_user&.stripeCustomerID)
    @stripeCustomerSubsctiptions = Stripe::Subscription.list({ limit: 100, customer: current_user&.stripeCustomerID })['data']

    @stripeCustomerSubsctiptions.each do |subInfo|
      @subscriptionList << {active: subInfo['pause_collection'].nil? ? true : false, price: subInfo['items']['data'].map(&:price).map(&:id).first, subscription: subInfo['id']}
    end

    successURL = "https://card.twbcc.com/new-password-set?session={CHECKOUT_SESSION_ID}"
    customFields = [{
      key: 'type',
      label: { custom: 'Include Membership Card ($5)', type: 'custom' },
      type: 'dropdown',
      dropdown: { options: [
        { label: 'Yes', value: 'yes' },
        { label: 'No', value: 'no' }
      ] }
    }]
    @authBasicSession = Stripe::Checkout::Session.create({
      success_url: successURL,
      phone_number_collection: {
       enabled: true
      },
      custom_fields: customFields,
      customer: current_user&.stripeCustomerID,
      line_items: [
       { price: ENV['basicMembership'], quantity: 1 }
      ],
      mode: 'subscription'
    })
    @authBizSession = Stripe::Checkout::Session.create({
      success_url: successURL,
      phone_number_collection: {
       enabled: true
      },
      custom_fields: customFields,
      customer: current_user&.stripeCustomerID,
      line_items: [
       { price: ENV['executiveMembership'], quantity: 1 }
      ],
      mode: 'subscription'
    })
    @authEquitySession = Stripe::Checkout::Session.create({
      success_url: successURL,
      phone_number_collection: {
       enabled: true
      },
      custom_fields: customFields,
      customer: current_user&.stripeCustomerID,
      line_items: [
       { price: ENV['equityMembership'], quantity: 1 }
      ],
      mode: 'subscription'
    })
  end

  def resume_membership
    Stripe::Subscription.update(
      params['id'],
      {
        pause_collection: ''
      }
    )

    flash[:success] = 'Subscription Resumed'
    redirect_to request.referrer
  end

  def pause_membership
    # only pause of ID passed
    Stripe::Subscription.update(params['id'], {pause_collection: {behavior: 'void' }})

    flash[:success] = 'Subscription Paused'
    redirect_to request.referrer
  end

  def memberships
    successURL = "https://card.twbcc.com/new-password-set?session={CHECKOUT_SESSION_ID}"
    customFields = [{
      key: 'type',
      label: { custom: 'Include Membership Card ($5)', type: 'custom' },
      type: 'dropdown',
      dropdown: { options: [
        { label: 'Yes', value: 'yes' },
        { label: 'No', value: 'no' }
      ] }
    }]

    @basicSession = Stripe::Checkout::Session.create({
      success_url: successURL,
      phone_number_collection: {
       enabled: true
      },
      custom_fields: customFields,
      line_items: [
       { price: ENV['basicMembership'], quantity: 1 }
      ],
      mode: 'subscription'
    })

    @basicPrice = Stripe::Price.retrieve(ENV['basicMembership'])
    @basicProduct = Stripe::Product.retrieve(@basicPrice['product'])



    @bizSession = Stripe::Checkout::Session.create({
      success_url: successURL,
      phone_number_collection: {
       enabled: true
      },
      custom_fields: customFields,
      line_items: [
       { price: ENV['executiveMembership'], quantity: 1 }
      ],
      mode: 'subscription'
    })

    @bizPrice = Stripe::Price.retrieve(ENV['executiveMembership'])
    @bizProduct = Stripe::Product.retrieve(@basicPrice['product'])

    @equitySession = Stripe::Checkout::Session.create({
      success_url: successURL,
      phone_number_collection: {
       enabled: true
      },
      custom_fields: customFields,
      line_items: [
       { price: ENV['equityMembership'], quantity: 1 }
      ],
      mode: 'subscription'
    })

    @equityPrice = Stripe::Price.retrieve(ENV['equityMembership'])
    @equityProduct = Stripe::Product.retrieve(@basicPrice['product'])
    
  end

  def membership_card
    successURL = "https://card.twbcc.com/new-password-set?session={CHECKOUT_SESSION_ID}"
    customFields = [{
      key: 'type',
      label: { custom: 'Include Membership Card ($5)', type: 'custom' },
      type: 'dropdown',
      dropdown: { options: [
        { label: 'Yes', value: 'yes' },
        { label: 'No', value: 'no' }
      ] }
    }]

    @session = Stripe::Checkout::Session.create({
      success_url: successURL,
      phone_number_collection: {
       enabled: true
      },
      shipping_address_collection: {
        allowed_countries: ['US']
      },
      custom_fields: customFields,
      line_items: [
       { price: 'price_1NiJRWHvKdEDURjLEOuvHIKM', quantity: 1 }
      ],
      mode: 'payment'
    })

    redirect_to @session['url']
  end

  def external
    @link = 'https://oarlin.com/learn-trading' 
  end

  def traders
  end

  def captains
  end

  def users
    
  end

  def skip
  end

  def invite
    
  end

  def travel_trade
  end

  def inquiry
    if params['newInquiry'].present?
      customMade = Custominquiry.create(email: params['newInquiry']['email'], phone: params['newInquiry']['phone'], interval: params['newInquiry']['interval'], memberType: params['newInquiry']['memberType'])

      if customMade.present?
        flash[:success] = 'Inquiry Submitted'
        # text me
        oarlinMessage = "#{params['newInquiry']['email']} Joined The Waiting List!"
        textSent = User.twilioText(params['newInquiry']['phone'], "#{oarlinMessage}")
        redirect_to request.referrer
      else
        flash[:error] = 'Something Happened'
        redirect_to membership_path
      end
    else
      flash[:error] = 'Something Happened'
      redirect_to request.referrer
    end
  rescue Exception => e
    flash[:error] = e.to_s
    redirect_to request.referrer
  end

  def update_discount
    membershipDetails = current_user&.checkMembership
    subscriptions = Stripe::Subscription.list({ limit: 100, customer: current_user&.stripeCustomerID })
    subscriptions.each do |subs|
      Stripe::Subscription.update(
        subs['id'],
        { coupon: session['coupon'] }
      )
    end
    flash[:success] = 'Coupon Claimed'
    redirect_to profile_path
  rescue Stripe::StripeError => e
    flash[:error] = e.error.message.to_s
    redirect_to request.referrer
  rescue Exception => e
    flash[:error] = e.to_s
    redirect_to request.referrer
  end

  def discounts # sprint2
    if session['coupon'].nil?
      @discountsFor = current_user&.present? ? current_user&.checkMembership : nil
      @discountList = Stripe::Coupon.list({ limit: 100 })['data'].reject { |c| c['valid'] == false }.reject { |c| c['duration'] == 'forever' }.reject { |c| c['max_redemptions'] == 0 }

      if @discountsFor.nil? || !@discountsFor.map { |s| s[:membershipType] }.include?('free')
        
        @newList = @discountList.reject { |c| c['percent_off'] > 10 }.reject { |c| c['percent_off'] > 90 }.size > 0 ? @discountList.reject { |c| c['percent_off'] > 10 }.reject { |c| c['percent_off'] > 90 }.sample['id'] : 0
      elsif @discountsFor.map { |s| s[:membershipType] }.include?('affiliate')
        @newList = @discountList.reject { |c| c['percent_off'] > 20 || c['percent_off'] < 10 }.reject { |c| c['percent_off'] > 90 }.size > 0 ? @discountList.reject { |c| c['percent_off'] > 20 || c['percent_off'] < 10 }.reject { |c| c['percent_off'] > 90 }.sample['id'] : 0
      elsif @discountsFor.map { |s| s[:membershipType] }.include?('business')
        @newList = @discountList.reject { |c| c['percent_off'] > 30 || c['percent_off'] < 20 }.reject { |c| c['percent_off'] > 90 }.size > 0 ? @discountList.reject { |c| c['percent_off'] > 30 || c['percent_off'] < 20 }.reject { |c| c['percent_off'] > 90 }.sample['id'] : 0
      elsif @discountsFor.map { |s| s[:membershipType] }.include?('automation')
        @newList = @discountList.reject { |c| c['percent_off'] > 40 || c['percent_off'] < 30 }.reject { |c| c['percent_off'] > 90 }.size > 0 ? @discountList.reject { |c| c['percent_off'] > 40 || c['percent_off'] < 30 }.reject { |c| c['percent_off'] > 90 }.sample['id'] : 0
      elsif @discountsFor.map { |s| s[:membershipType] }.include?('custom')
        @newList = @discountList.reject { |c| c['percent_off'] > 50 || c['percent_off'] < 40 }.reject { |c| c['percent_off'] > 90 }.size > 0 ? @discountList.reject { |c| c['percent_off'] > 50 || c['percent_off'] < 40 }.reject { |c| c['percent_off'] > 90 }.sample['id'] : 0
      end

      session['coupon'] = @newList
    else
      if Stripe::Coupon.list({ limit: 100 }).map(&:id).include?(session['coupon']) == true
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
      codes = Stripe::Coupon.list({ limit: 100 })['data'].reject { |c| c['valid'] == false }.reject { |c| c['duration'] == 'forever' }.reject { |c| c['max_redemptions'] == 0 }
      if codes.size > 0
        session['coupon'] = codes.sample['id']
        flash[:success] = 'Coupon Assigned'
        redirect_to request.referrer
        nil
      else
        flash[:notice] = 'Waiting For New Coupons'
        redirect_to discounts_path
        nil
      end
    end
  end

  def split_session
    redirect_to "#{request.fullpath.split('?')[0]}?&referredBy=#{params[:splitSession]}"
  end

  def cancel
    allSubscriptions = Stripe::Subscription.list({ customer: current_user&.stripeCustomerID })['data'].map(&:id)
    allSubscriptions.each do |id|
      upda = Stripe::Subscription.update(id, {pause_collection: {
        behavior: 'keep_as_draft' }})
    end


    flash[:success] = 'Membership Paused'
    redirect_to request.referrer
  end

  def commissions
    affiliateFromId = User.find_by(uuid: params[:id])
    @pulledAffiliate = Stripe::Customer.retrieve(affiliateFromId&.stripeCustomerID)
    @pulledCommissions = Stripe::Customer.list(limit: 100)
    @accountsFromAffiliate = @pulledCommissions['data'].reject { |e| e['metadata']['referredBy'] != params[:id] }
    @activeSubs = []
    @inactiveSubs = []
    @accountItemsDue = Stripe::Account.retrieve(Stripe::Customer.retrieve(affiliateFromId&.stripeCustomerID)['metadata']['connectAccount'])['requirements']['currently_due']
    @accountsFromAffiliate.each do |cusID|
      listofSubscriptionsFromCusID = Stripe::Subscription.list(limit: 100, customer: cusID)['data']
      next unless listofSubscriptionsFromCusID.size > 0

      listofSubscriptionsFromCusID.each do |subscriptionX|
        if subscriptionX['status'] == 'active'
          @activeSubs << subscriptionX
        else
          @inactiveSubs << subscriptionX
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

      next unless plan['interval'] == 'year'

      @combinedCommissions += (plan['amount']) * (@pulledAffiliate['metadata']['commissionRate'].to_i * 0.01)
      @annualCommissions += 1
    end

    @combinedCommissions

    @payouts = Stripe::Payout.list({ limit: 3 }, { stripe_account: @pulledAffiliate['metadata']['connectAccount'] })['data']
  rescue Stripe::StripeError => e
    flash[:error] = e.error.message.to_s
    redirect_to request.referrer
  rescue Exception => e
    flash[:error] = e.to_s
    redirect_to request.referrer
  end

  def analytics; end

  def checkout
    customFields = [
      {
        key: 'asset',
        label: { custom: 'Choose Your Market', type: 'custom' },
        type: 'dropdown',
        dropdown: { options: [
          # {label: 'Options', value: 'options'},
          { label: 'Crypto', value: 'crypto' },
          { label: 'Forex', value: 'forex' },
          { label: 'Stocks', value: 'stocks' },
          { label: 'Options', value: 'options' }
        ] }
      }
    ]
    begin
      if params['account'].present?
        applicationFeeAmount = Stripe::Price.retrieve(params['price'], { stripe_account: params['account'] })['unit_amount'] * 0.02
        @session = Stripe::Checkout::Session.create({
                                                      success_url: "https://app.oarlin.com/?session={CHECKOUT_SESSION_ID}&referredBy=#{params['referredBy']}",
                                                      phone_number_collection: {
                                                        enabled: true
                                                      },
                                                      payment_intent_data: {
                                                        application_fee_amount: applicationFeeAmount.to_i
                                                      },
                                                      line_items: [
                                                        { price: params['price'], quantity: 1 }
                                                      ],
                                                      mode: 'payment'
                                                    }, { stripe_account: params['account'] })
      else
        if params['trial'] == 'true'
          pullPrice = Stripe::Price.retrieve(params['price'])

          @session = Stripe::Checkout::Session.create({
                                                        success_url: "https://app.oarlin.com/trading?session={CHECKOUT_SESSION_ID}&referredBy=#{params['referredBy']}", # let stripe data determine
                                                        phone_number_collection: {
                                                          enabled: true
                                                        },
                                                        custom_fields: customFields,
                                                        line_items: [
                                                          { price: params['price'], quantity: 1 }
                                                        ],
                                                        mode: 'subscription' # let stripe data determine
                                                      })
        else
          tradeCoupon = Stripe::Coupon.list({ limit: 100 })['data'].reject { |c| c['max_redemptions'] == 0 }.reject { |c| c['duration'] == 'forever' }
          grabStripePrice = Stripe::Price.retrieve(params['price'])

          if tradeCoupon.present?
            @session = Stripe::Checkout::Session.create({
                                                          success_url: "https://app.oarlin.com/trading?session={CHECKOUT_SESSION_ID}&referredBy=#{params['referredBy']}", # let stripe data determine
                                                          phone_number_collection: {
                                                            enabled: true
                                                          },
                                                          custom_fields: customFields,
                                                          line_items: [
                                                            { price: params['price'], quantity: 1 }
                                                          ],
                                                          discounts: [
                                                            coupon: tradeCoupon.first
                                                          ],
                                                          mode: 'subscription' # let stripe data determine,
                                                        })
          else
            @session = Stripe::Checkout::Session.create({
                                                          success_url: "https://app.oarlin.com/trading?session={CHECKOUT_SESSION_ID}&referredBy=#{params['referredBy']}", # let stripe data determine
                                                          phone_number_collection: {
                                                            enabled: true
                                                          },
                                                          custom_fields: customFields,
                                                          line_items: [
                                                            { price: params['price'], quantity: 1 }
                                                          ],
                                                          mode: 'subscription' # let stripe data determine
                                                        })
          end
        end
      end
      redirect_to @session['url']
    rescue Stripe::StripeError => e
      session['coupon'] = nil
      flash[:error] = e.error.message.to_s
      redirect_to request.referrer
    rescue Exception => e
      session['coupon'] = nil
      flash[:error] = e.to_s
      redirect_to request.referrer
    end
  end

  def profile
    current_user&.checkMembership
    builtPayload = []

    @userFound = params['id'].present? ? User.find_by(uuid: params['id']) : current_user
    @profile = @userFound.present? ? Stripe::Customer.retrieve(@userFound&.stripeCustomerID) : nil
    @issuingTransactions = Stripe::Issuing::Authorization.list({card: @profile['metadata']['issuedCard']})['data'].reject{|d| d['approved'] != true}
    @deposits = Stripe::Charge.list({limit: 100, customer: current_user&.stripeCustomerID}).reject{|d| !d['metadata']['topUp'].present?}

    builtPayload << @issuingTransactions.map{|d| {created: DateTime.strptime(d['created'].to_s,'%s'), item: d['merchant_data']['name'], status: d['approved'] == true ? 'Approved' : 'Declined', amount: d['amount'].to_i}}.flatten
    builtPayload << @deposits.map{|d| {created: DateTime.strptime(d['created'].to_s,'%s'), item: 'Deposit', status: 'Approved', amount: d['metadata']['requestAmount'].to_i}}.reject{|d| d[:amount] == 0}.flatten
    transactions = @issuingTransactions.map(&:amount).sum * 0.01
    @balance = @deposits.map{|d| d['metadata']['requestAmount'].to_i}.sum * 0.01 - transactions
    @builtPayload = builtPayload.flatten
  end

  def welcome
  end

end
