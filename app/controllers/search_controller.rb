#/discover
class SearchController < ApplicationController
	def index
		@codes = current_user.present? ? Stripe::Coupon.list({limit: 100}).reject{|c| c['valid'] == false}.reject{|c| c['percent_off'] > 90} : Stripe::Coupon.list({limit: 100}).reject{|c| c['valid'] == false}.reject{|c| c['percent_off'] > 10}.reject{|c| c['percent_off'] > 90}
		
		if params['newSearch'].present? && newSearchParams[:for].present?
			@query = newSearchParams[:for]
			@country = newSearchParams[:country]

			if session['search'].present?
				if session['search'].map{|d| d[:query]}.include?(@query)
					session['search'].each do |info|
						if info[:query] == @query && info[:data].present?
							# show cache data to paginate
							ahoy.track "Cache Search Term", previousPage: request.referrer, query: @query, referredBy: params['referredBy'].present? ? params['referredBy'] : current_user.present? ? current_user.uuid : 'admin'
							@searchResults = info[:data].paginate(page: params['page'], per_page: 8)
						end
					end
				else
					#paginate
					ahoy.track "New Search Term", previousPage: request.referrer, query: @query, referredBy: params['referredBy'].present? ? params['referredBy'] : current_user.present? ? current_user.uuid : 'admin'
					session['search'] |= [{query: @query, data: @searchResults, country: @country}]
					@searchResults = User.rainforestSearch(@query, @country)[0][:data].paginate(page: params['page'], per_page: 8)
				end

			else
				session['search'] = []
				#paginate
				ahoy.track "New Search Term", previousPage: request.referrer, query: @query, referredBy: params['referredBy'].present? ? params['referredBy'] : current_user.present? ? current_user.uuid : 'admin'
				session['search'] |= [{query: @query, data: @searchResults, country: @country}]
				@searchResults = User.rainforestSearch(@query, @country)[0][:data].paginate(page: params['page'], per_page: 8)
			end



			#analytics
			#stash results of search in session -> render when search repeats sprint2
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