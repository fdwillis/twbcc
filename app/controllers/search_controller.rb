#/discover
class SearchController < ApplicationController
	def index
		if params[:for].present?
			#analytics
			ahoy.track "Search Terms", query: params[:for]
		end 
	end
end