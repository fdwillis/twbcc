#/discover
class SearchController < ApplicationController
	def index
		if params[:for].present?
			#analytics
			debugger
			ahoy.track "Search Terms", previousPage: request.referrer, query: params[:for], referredBy: params['referredBy'].present? ? params['referredBy'] : current_user.present? ? current_user.uuid : 'admin'
		else
			@searchResults = User.autoSearchCategories
			@searchCategories = User.autoSearchCategories
		end 
	end


	
	def newSearchParams
    paramsClean = params.require(:newSearch).permit(:for, :page)
    return paramsClean.reject{|_, v| v.blank?}
  end
end