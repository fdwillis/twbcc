# /discover
class SearchController < ApplicationController
  def index
    loadMemberships

    @codes = current_user.present? ? Stripe::Coupon.list({ limit: 100 }).reject { |c| c['valid'] == false }.reject { |c| c['percent_off'] > 90 } : Stripe::Coupon.list({ limit: 100 }).reject { |c| c['valid'] == false }.reject { |c| c['percent_off'] > 10 }.reject { |c| c['percent_off'] > 90 }

    if params['newSearch'].present? && newSearchParams[:for].present?
      @query = newSearchParams[:for]
      @country = newSearchParams[:country]

      if session['search'].present?
        if session['search'].map { |d| d[:query] }.include?(@query)
          session['search'].each do |infox|
            next unless infox[:query] == @query && infox[:data].present?

            # show cache data to paginate
            @searchResults = infox[:data].paginate(page: params['page'], per_page: 6)
            return
          end
        else
          # paginate

          searchResults = User.rainforestSearch(@query, nil, @country)
          session['search'] |= [{ query: @query, data: searchResults, country: @country }]
          @searchResults = searchResults.paginate(page: params['page'], per_page: 6)
          nil
        end

      else
        session['search'] = []
        # paginate

        searchResults = User.rainforestSearch(@query, nil, @country)

        session['search'] |= [{ query: @query, data: searchResults, country: @country }]
        @searchResults = searchResults.paginate(page: params['page'], per_page: 6)
        nil
      end

      # analytics
      # stash results of search in session -> render when search repeats sprint2
    else
      @limitedPublished = Category.where(featured: true, published: true).limit(10)
      @categories = (Category.where(published: true) - @limitedPublished).paginate(page: params['page'], per_page: 6)
      nil
    end
  end

  def newSearchParams
    paramsClean = params.require(:newSearch).permit(:for, :page, :country)
    paramsClean.reject { |_, v| v.blank? }
  end
end
