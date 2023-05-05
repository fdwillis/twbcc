#/discover
class SearchController < ApplicationController
	def index
		if params[:for].present?
			ahoy.track "Search Terms", query: params[:for]
		end 
	end
end