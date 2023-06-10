require 'clockwork'
include Clockwork

every(2.days, 'delete.discounts', :at => '23:00') {'rake generate:deleteDiscounts'}
every(2.days, 'generate.discounts', :at => '00:00') {'rake generate:discounts'}

every(1.day, 'trading.referrals', :at => '00:00') {'rake generate:tradingReferrals'}
every(1.day, 'trading.referrals', :at => '06:00') {'rake generate:tradingReferrals'}
every(1.day, 'trading.referrals', :at => '12:00') {'rake generate:tradingReferrals'}
every(1.day, 'trading.referrals', :at => '18:00') {'rake generate:tradingReferrals'}
