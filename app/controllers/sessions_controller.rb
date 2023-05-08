class SessionsController < Devise::SessionsController
	def after_sign_in_path_for(resource)
    "#{root_path}?&referredBy=#{current_user&.present? ? current_user&.uuid : params['referredBy']}"
	end
end