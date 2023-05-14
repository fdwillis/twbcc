#/discover
class SearchController < ApplicationController
	def index
		if params['newSearch'].present? && newSearchParams[:for].present?
			#analytics
			ahoy.track "Search Terms", previousPage: request.referrer, query: newSearchParams[:for], referredBy: params['referredBy'].present? ? params['referredBy'] : current_user.present? ? current_user.uuid : 'admin'
			@searchResults = User.autoSearchCategories
			@searchCategories = User.autoSearchCategories
		else
			@searchResults = User.autoSearchCategories
			@searchCategories = User.autoSearchCategories
		end 
	end


	
	def newSearchParams
    paramsClean = params.require(:newSearch).permit(:for, :page, :country)
    return paramsClean.reject{|_, v| v.blank?}
  end
end