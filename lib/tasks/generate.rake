namespace :generate do

  task discounts: :environment do
    desc 'create discounts by OWNER SETTTINGS level & delete old codes'

    User.all.each do |userX|
      if userX.biz?
        connectAccountID = Stripe::Customer.retrieve(userX&.stripeCustomerID)['metadata']['connectAccount']
        stripeConnectAccount = Stripe::Account.retrieve(Stripe::Customer.retrieve(userX&.stripeCustomerID)['metadata']['connectAccount'])
        metaX = stripeConnectAccount['metadata'] 


        if metaX.present?
          stripeCodes = Stripe::Coupon.list({limit: 100}, stripe_account: connectAccountID )['data']
          @codesToReject = stripeCodes.reject{|f|Time.now.to_i < f['redeem_by']}
          
          @codesToReject.each do |codeX|
            Stripe::Coupon.delete(codeX['id'])
          end
          
          unless stripeCodes.present?
            metaX['maxDiscount'].to_i.times.each do |disInt|
              Stripe::Coupon.create({
                percent_off: disInt + 1,
                duration: 'once',
                max_redemptions: metaX['redemptions'].to_i,
                redeem_by: (Date.today + metaX['refreshRate'].to_i.days).to_time.to_i ,
              }, stripe_account: connectAccountID)
            end
          end
        end
      end
    end

    # freePercentages = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    # freePercentages.each do |num|
    #   Stripe::Coupon.create({
    #                           percent_off: num,
    #                           duration: 'once',
    #                           max_redemptions: 500,
    #                           redeem_by: (Date.today + 2.days).to_time.to_i
    #                         })
  end
end
