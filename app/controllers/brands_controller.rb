class BrandsController < ApplicationController
  before_action :set_brand, only: %i[show edit update destroy]
  before_action :checkAdmin, only: %i[new create update]

  # GET /brands or /brands.json
  def index
    @brands = Brand.all
  end

  # GET /brands/1 or /brands/1.json
  def show
    # call to rain for product with search_alias / amazonCategory
    @query = @brand.title
    @country = @brand.countries.split(',').sample

    thisAmazonCat = @brand.amazonCategory

    if session['search'].present?
      if session['search'].map { |d| d[:query] }.include?(@query) && session['search'].map { |d| d[:amazonCategory] }.include?(thisAmazonCat) && session['search'].map { |d| d[:country] }.include?(@country)
        session['search'].each do |info|
          if info[:query] == @query && info[:data].present?
            # show cache data to paginate
            @searchResults = info[:data].shuffle.paginate(page: params['page'], per_page: 6)
          end
        end
      else
        # paginate

        searchResults = User.rainforestSearch(@query, thisAmazonCat, @country)
        @searchResults = searchResults.paginate(page: params['page'], per_page: 6)
        session['search'] |= [{ amazonCategory: thisAmazonCat, query: @query, data: searchResults, country: @country }]
      end

    else
      session['search'] = []
      # paginate
      searchResults = User.rainforestSearch(@query, thisAmazonCat, @country)
      @searchResults = searchResults.paginate(page: params['page'], per_page: 6)
      session['search'] |= [{ amazonCategory: thisAmazonCat, query: @query, data: @searchResults, country: @country }]
    end
  end

  # GET /brands/new
  def new
    @brand = Brand.new
  end

  # GET /brands/1/edit
  def edit; end

  # POST /brands or /brands.json
  def create
    @brand = Brand.new(title: brand_params[:title], tags: brand_params[:tags], images: brand_params[:images], countries: params['brand']['countries'].join(','), categories: params['brand']['categories'].join(','))

    respond_to do |format|
      if @brand.save
        format.html { redirect_to brand_url(@brand), notice: 'Brand was successfully created.' }
        format.json { render :show, status: :created, location: @brand }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @brand.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /brands/1 or /brands/1.json
  def update
    respond_to do |format|
      if @brand.update(amazonCategory: brand_params[:amazonCategory], slug: brand_params[:title].parameterize(separator: '-'), title: brand_params[:title], tags: brand_params[:tags], images: brand_params[:images], countries: params['brand']['countries'].join(','), categories: params['brand']['categories'].join(','))
        format.html { redirect_to brand_url(@brand), notice: 'Brand was successfully updated.' }
        format.json { render :show, status: :ok, location: @brand }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @brand.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /brands/1 or /brands/1.json
  def destroy
    @brand.destroy

    respond_to do |format|
      format.html { redirect_to brands_url, notice: 'Brand was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_brand
    @brand = Brand.friendly.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def brand_params
    params.require(:brand).permit(:amazonCategory, :title, :tags, :countries, :images, :categories).reject { |_, v| v.blank? }
  end

  def checkAdmin
    unless current_user&.admin? || current_user&.trustee?
      flash[:error] = 'Admin Only'
      redirect_to root_path
    end
  end
end
