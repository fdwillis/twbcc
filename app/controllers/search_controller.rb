#/discover
class SearchController < ApplicationController
	def index
		loadMemberships
		
		@codes = current_user.present? ? Stripe::Coupon.list({limit: 100}).reject{|c| c['valid'] == false}.reject{|c| c['percent_off'] > 90} : Stripe::Coupon.list({limit: 100}).reject{|c| c['valid'] == false}.reject{|c| c['percent_off'] > 10}.reject{|c| c['percent_off'] > 90}
		
		if params['newSearch'].present? && newSearchParams[:for].present?
			@query = newSearchParams[:for]
			@country = newSearchParams[:country]

			if session['search'].present?
				if session['search'].map{|d| d[:query]}.include?(@query)
					session['search'].each do |infox|
						
						if infox[:query] == @query && infox[:data].present?
							# show cache data to paginate
							ahoy.track "Cache Search Term", pageNumber: params['page'], previousPage: request.referrer, query: @query, referredBy: params['referredBy'].present? ? params['referredBy'] : current_user.present? ? current_user.uuid : 'admin'
							@searchResults = infox[:data].paginate(page: params['page'], per_page: 6)
							return
						end
					end
				else
					#paginate

					ahoy.track "New Search Term",pageNumber: params['page'], previousPage: request.referrer, query: @query, referredBy: params['referredBy'].present? ? params['referredBy'] : current_user.present? ? current_user.uuid : 'admin'
					
					searchResults = User.rainforestSearch(@query, nil, @country)
					session['search'] |= [{query: @query, data: searchResults, country: @country}]
					@searchResults = searchResults.paginate(page: params['page'], per_page: 6)
					return
				end

			else
				session['search'] = []
				#paginate
				ahoy.track "New Search Term",pageNumber: params['page'], previousPage: request.referrer, query: @query, referredBy: params['referredBy'].present? ? params['referredBy'] : current_user.present? ? current_user.uuid : 'admin'
				
				searchResults = User.rainforestSearch(@query, nil, @country)

				session['search'] |= [{query: @query, data: searchResults, country: @country}]
				@searchResults = searchResults.paginate(page: params['page'], per_page: 6)
				return
			end



			#analytics
			#stash results of search in session -> render when search repeats sprint2
		else
			@limitedPublished = Category.where(featured: true, published: true).limit(10)
			@categories = (Category.where(published: true) - @limitedPublished).paginate(page: params['page'], per_page: 6)
		end 
	end


	
	def newSearchParams
    paramsClean = params.require(:newSearch).permit(:for, :page, :country)
    return paramsClean.reject{|_, v| v.blank?}
  end
end