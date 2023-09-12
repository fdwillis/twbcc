# tvData = {"direction"=>"buy", "ticker"=>"EURJPY", "traderID"=>"d57307d7", "broker"=>"OANDA", 'type' => 'kill', 'killType' => 'all'}
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  

  # combine limit and market into one 'entry' call with logic to determine wich
end
