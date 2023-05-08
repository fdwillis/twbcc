class ErrorsController < ApplicationController

  def show
    # debugger
    @status_code = params[:code] || 500
    flash['error'] = "Status #{@status_code} #{flash[:error]}"
    render :show
  end

end