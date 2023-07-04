class CategoriesController < ApplicationController
  before_action :set_category, only: %i[show edit update destroy activate]
  before_action :checkAdmin, except: %i[show]

  def activate
    @category.update(published: true)
    flash[:success] = 'Activated'
    redirect_to categories_path
  end

  # GET /categories or /categories.json
  def index
    @categories = Category.all
  end

  # GET /categories/1 or /categories/1.json
  def show
    @brands = Brand.where('categories like ?', @category.title).paginate(page: params['page'], per_page: 6)
  end

  # GET /categories/new
  def new
    @category = Category.new
  end

  # GET /categories/1/edit
  def edit; end

  # POST /categories or /categories.json
  def create
    @category = Category.new(category_params.merge(slug: category_params[:title].parameterize(separator: '-')))

    respond_to do |format|
      if @category.save
        format.html { redirect_to category_url(@category), notice: 'Category was successfully created.' }
        format.json { render :show, status: :created, location: @category }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /categories/1 or /categories/1.json
  def update
    respond_to do |format|
      if @category.update(category_params.merge(slug: category_params[:title].parameterize(separator: '-')))
        format.html { redirect_to category_url(@category), notice: 'Category was successfully updated.' }
        format.json { render :show, status: :ok, location: @category }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /categories/1 or /categories/1.json
  def destroy
    @category.destroy

    respond_to do |format|
      format.html { redirect_to categories_url, notice: 'Category was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_category
    @category = Category.friendly.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def category_params
    params.require(:category).permit(:title, :description, :tags, :images, :featured, :published).reject { |_, v| v.blank? }
  end

  def checkAdmin
    unless current_user&.admin? || current_user&.trustee?
      flash[:error] = 'Admin Only'
      redirect_to root_path
    end
  end
end
