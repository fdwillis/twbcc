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
    deleteCoupons = Stripe::Coupon.list({limit: 100})['data']

    if deleteCoupons.size > 0 
      deleteCoupons.each do |coupon| 
        Stripe::Coupon.delete(coupon['id'])
      end
    end
  end

  task discounts: :environment do 
    desc 'create discounts by membership level'
    #free
    #first come first serve -> will have array, only show one group at a time until all gone from best deal to worst
    
    freePercentages = [1,2,3,4,5,6,7,8,9,10]
    freePercentages.each do |num|
      coupon = Stripe::Coupon.create({
        percent_off: num,
        duration: 'repeating',
        duration_in_months: 2,
        max_redemptions: 1,
        # max_redemptions: 50,
        redeem_by: (Date.today + 2.days).to_time.to_i
      })
    end


    affiliatePercentages = [11,12,13,14,15,16,17,18,19,20]
    
    affiliatePercentages.each do |num|
      coupon = Stripe::Coupon.create({
        percent_off: num,
        duration: 'repeating',
        duration_in_months: 3,
        max_redemptions: 1,
        # max_redemptions: 250,
        redeem_by: (Date.today + 2.days).to_time.to_i
      })
    end


    
    businessPercentages = [21,22,23,24,25,26,27,28,29,30]
    
    businessPercentages.each do |num|
      Stripe::Coupon.create({
        percent_off: num,
        duration: 'repeating',
        duration_in_months: 6,
        max_redemptions: 1,
        # max_redemptions: 500,
        redeem_by: (Date.today + 2.days).to_time.to_i
      })
    end
    #automation

    automationPercentages = [31,32,33,34,35,36,37,38,39,40]
    automationPercentages.each do |num|
      Stripe::Coupon.create({
        percent_off: num,
        duration: 'repeating',
        duration_in_months: 9,
        max_redemptions: 1,
        # max_redemptions: 1000,
        redeem_by: (Date.today + 2.days).to_time.to_i
      })
    end
    #custom
    customPercentages = [41,42,43,44,45,46,47,48,49,50]
    customPercentages.each do |num|
      Stripe::Coupon.create({
        percent_off: num,
        duration: 'repeating',
        duration_in_months: 12,
        max_redemptions: 1,
        # max_redemptions: 2500,
        redeem_by: (Date.today + 2.days).to_time.to_i
      })
    end

    #sprint2 one winner every 3 months, must participate in lotery up to date for eligibility
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

  # task lifetime: :environment do
  #   # (1/1000000) odds -> $1 raffle per month
  #   # annual selection
  #   Stripe::Coupon.create({
  #     percent_off: 100,
  #     duration: 'forever',
  #     currency_options: availableCurrencies
  #   })
  # end
end