class SessionsController < Devise::SessionsController
	after_action :checkMembership

	def checkMembership
	  resource&.checkMembership
	end
end