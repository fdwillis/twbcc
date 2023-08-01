namespace :generate do
  # Stripe::Coupon.list({limit: 3})
  # free -> 1 -> once -> max red 50 -> 10%
  # affiliate -> 3 -> repeating -> max red 250 -> 20%
  # business -> 6 -> repeating -> max red 500 -> 30% -> lifetime available
  # automation -> 9 -> repeating -> max red 1000 -> 40% -> lifetime available
  # custom -> 12 -> repeating -> max red 2500 -> 50% -> lifetime available

  # use times_redeemed count to create urgency on discounts page

  # availableCurrencies = User::ACCEPTEDcountries.map{|d| d[1]}.map{|d| d[:currency]}
  task deleteDiscounts: :environment do
    deleteCoupons = Stripe::Coupon.list({ limit: 100 })['data']

    if deleteCoupons.size > 0
      deleteCoupons.each do |coupon|
        Stripe::Coupon.delete(coupon['id'])
      end
    end
  end

  task discounts: :environment do
    desc 'create discounts by membership level'
    # free
    # first come first serve -> will have array, only show one group at a time until all gone from best deal to worst

    freePercentages = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    freePercentages.each do |num|
      Stripe::Coupon.create({
                              percent_off: num,
                              duration: 'once',
                              max_redemptions: 500,
                              redeem_by: (Date.today + 2.days).to_time.to_i
                            })
    end

    affiliatePercentages = [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]

    affiliatePercentages.each do |num|
      Stripe::Coupon.create({
                              percent_off: num,
                              duration: 'once',
                              max_redemptions: 400,
                              redeem_by: (Date.today + 2.days).to_time.to_i
                            })
    end

    businessPercentages = [21, 22, 23, 24, 25, 26, 27, 28, 29, 30]

    businessPercentages.each do |num|
      Stripe::Coupon.create({
                              percent_off: num,
                              duration: 'once',
                              max_redemptions: 300,
                              redeem_by: (Date.today + 2.days).to_time.to_i
                            })
    end
    # automation

    automationPercentages = [31, 32, 33, 34, 35, 36, 37, 38, 39, 40]
    automationPercentages.each do |num|
      Stripe::Coupon.create({
                              percent_off: num,
                              duration: 'once',
                              max_redemptions: 200,
                              redeem_by: (Date.today + 2.days).to_time.to_i
                            })
    end
    # custom
    customPercentages = [41, 42, 43, 44, 45, 46, 47, 48, 49, 50]
    customPercentages.each do |num|
      Stripe::Coupon.create({
                              percent_off: num,
                              duration: 'once',
                              max_redemptions: 100,
                              redeem_by: (Date.today + 2.days).to_time.to_i
                            })
    end

    # 50% lifetime
    customPercentages = [50]
    customPercentages.each do |num|
      Stripe::Coupon.create({
                              percent_off: num,
                              duration: 'forever',
                              max_redemptions: 100,
                              # max_redemptions: 2500,
                              redeem_by: (Date.today + 2.days).to_time.to_i
                            })
    end

    # sprint2 one winner every 3 months, must participate in lotery up to date for eligibility
    # lifeTimePercentages = []
    # lifeTimePercentages.each do |num|
    #   Stripe::Coupon.create({
    #     percent_off: num,
    #     duration: 'repeating',
    #     duration_in_months: 12,
    #     max_redemptions: 1,
    #     # max_redemptions: 2500,
    #     redeem_by: (Date.today + 2.days).to_time.to_i
    #   })
    # end
  end

  task tradingReferrals: :environment do
    # if plan due tomorrow and 10 referrals -> skip subscription
    # uncollectable
    # resumes 30 days from date if monthly or 12 months if annual -> check status day before

    #  if currently uncollectable and less than 10 -> mark collectable
  end

  task cleanTrades: :environment do
    Trade.all.sort_by(&:created_at).each do |trade|
      userForLoad = trade.user
      if trade&.broker == 'KRAKEN'
          trade.destroy! 
      elsif trade&.broker == 'OANDA'
        begin
          trade&.user&.oandaList.split(',').each do |accountID|
            @requestTTrade = Oanda.oandaTrade(userForLoad.oandaToken, accountID, trade.uuid)
          end

          if @requestK['order']['state'] == 'CANCELLED'
            trade.destroy! if trade.status == 'canceled'
          end
          
          if @requestK['order']['type'] != 'LIMIT'
            trade.update(cost: @requestTTrade['trade']['initialMarginRequired'].to_f)
            trade.update(status: 'closed') if @requestK['order']['state'] == 'FILLED'
          end
          puts @requestTTrade
        rescue Exception => e
            puts e
            break
          
        end
      end
    end

    # TakeProfit.all.sort_by(&:created_at).each do |takeProfitX|
    #   userForLoad = takeProfitX.user

    #   if takeProfitX&.broker == 'KRAKEN'
    #       takeProfitX.destroy! 
    #   elsif takeProfitX&.broker == 'OANDA'

    #     userForLoad.oandaList.split(",").each do |accountID|
    #       @requestK = Oanda.oandaOrder(userForLoad.oandaToken, accountID, takeProfitX.uuid)

    #       if @requestK['order']['tradeReducedID'].present?
    #         @requestTTrade = Oanda.oandaTrade(userForLoad.oandaToken, accountID, @requestK['order']['tradeReducedID'])
    #       elsif  @requestK['order']['tradeClosedIDs'].present?
    #         @requestK['order']['tradeClosedIDs'].each do |tradeID|
    #           @requestTTrade = Oanda.oandaTrade(userForLoad.oandaToken, accountID, tradeID)
    #         end
    #       end

    #       if @requestK['order']['state'] == 'FILLED' && @requestTTrade['trade'].present?
    #         takeProfitX.update(status: 'closed')
    #         takeProfitX.update(profitLoss: @requestTTrade['trade']['realizedPL'].to_f)
    #       elsif @requestK['order']['state'] == 'PENDING'
    #         takeProfitX.update(status: 'open')
    #       elsif @requestK['order']['state'] == 'CANCELLED'
    #         takeProfitX.destroy!
    #       end
    #     end
    #   end
    # end
  end

  task profitInvoice: :environment do 
    # allSubscriptions.include?(planID)
    # membershipPlan = Stripe::Subscription.list({ customer: stripeCustomerID, price: planID })['data'][0]
    puts "cleaning database..."
    Rake::Task['generate:cleanTrades'].invoke

    User.all.each do |userX|
      profitTallyForUserX = 0
      permissionPass = false
      

      if userX.trader?
        if userX&.take_profits.present? && userX&.take_profits.map(&:stripePI).include?(nil)
          validTakeProfits = userX&.take_profits.where(stripePI: nil).sort_by(&:created_at)
          profitTallyForUserX += validTakeProfits.map(&:profitLoss).sum 

          if Date.today.strftime("%d").to_i == 1
            unless userX&.accessPin.include?('profit')
                permissionPass = true
            else
              # only run if last charge was at least 28 days ago
              userXIntents = Stripe::PaymentIntent.list(limit: 100, customer: userX.stripeCustomerID)
              if userXIntents['has_more'] == true
              else
                cleanedIntents = userXIntents['data'].reject{|d|!d['metadata'][:profitPaid].present?}

                cleanedIntents.each do |paymentIntent|
                  unless paymentIntent['cancellation_reason'].present?
                    if Time.at(cleanedIntents.last.created) < 28.days.ago
                      permissionPass = true
                    end
                  end
                end
              end
            end
            
            if permissionPass && profitTallyForUserX > 0
              createPaymentIntent = Stripe::PaymentIntent.create(
                amount: ((profitTallyForUserX * 100).to_i * (3 * 0.01)),
                currency: userX.currencyBase,
                customer: userX.stripeCustomerID,
                description: '3% Profit Fee',
                metadata: {
                  profitPaid: false
                }

              )

              validTakeProfits.each do |takeProfitX|
                takeProfitX.update(stripePI: createPaymentIntent)
                takeProfitX.trade.update(stripePI: createPaymentIntent)
              end

              if userX&.autoProfitPay
                Stripe::PaymentIntent.capture(createPaymentIntent['id'])
                Stripe::PaymentIntent.update(createPaymentIntent['id'], {
                  metadata: {
                    profitPaid: true
                  } 
                })
              end
            end
          else
            puts "not the day"
          end
        end
      end
    end
  end
end
