require 'clockwork'
include Clockwork

# every(1.day, 'issueProfit.ifCleared', :at => '00:00') {'rake issueProfit:ifCleared'}