#/discover
class SearchController < ApplicationController
	def index
		if params['newSearch'].present? && newSearchParams[:for].present?
			#analytics
			ahoy.track "Search Terms", previousPage: request.referrer, query: newSearchParams[:for], referredBy: params['referredBy'].present? ? params['referredBy'] : current_user.present? ? current_user.uuid : 'admin'

			@searchResults = 9
		else
			@limitedPublished = Category.where(featured: true, published: true).limit(10)
			@categories = (Category.where(published: true) - @limitedPublished).paginate(page: params['page'], per_page: 8)
		end 
	end


	
	def newSearchParams
    paramsClean = params.require(:newSearch).permit(:for, :page, :country)
    return paramsClean.reject{|_, v| v.blank?}
  end
end