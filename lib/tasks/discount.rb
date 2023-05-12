namespace :newCouponCodes do 
  
  task oneTo50: :environment do 
    1..50.each do |num|
      # free -> 1 -> once -> 50
      # affiliate -> 3 -> repeating -> 250
      # business -> 6 -> repeating -> 500
      # automation -> 9 -> repeating -> 1000
      # custom -> 12 -> repeating -> 2500
      Stripe::Coupon.create({
        percent_off: num,
        duration: 'repeating',
        duration_in_months: 3,
        max_redemptions: 3,
        currency_options: []
      })
      # use times_redeemed to create urgency on discounts page
    end
  end

  task lifetime: :environment do
    # (1/1000000) odds
    Stripe::Coupon.create({
      percent_off: 100,
      duration: 'forever',
      currency_options: []
    })
    # use times_redeemed to create urgency on discounts page
  end
end