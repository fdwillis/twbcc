require 'clockwork'
include Clockwork

every(2.days, 'delete.discounts', :at => '23:00') {'rake generate:deleteDiscounts'}
every(2.days, 'generate.discounts', :at => '00:00') {'rake generate:discounts'}
