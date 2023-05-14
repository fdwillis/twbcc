class ErrorsController < ApplicationController

  def show
    @status_code = params[:code] || 500
    flash['error'] = "Status #{@status_code} #{flash[:error]}"
    ahoy.track "Error", previousPage: request.referrer
    render :show
  end

end