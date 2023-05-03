#/trending
class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit update destroy ]

  # GET /products or /products.json
  def index
    @products = Product.all

    @userFound = params['referredBy'].present? ? User.find_by(uuid: params['referredBy']) : nil
    @profile = @userFound.present? ? Stripe::Customer.retrieve(@userFound.stripeCustomerID) : nil
    @membershipDetails = @userFound.present? ? @userFound.checkMembership : nil

      #split traffic 95/5
    case true
    when @membershipDetails&.present? && @membershipDetails[:membershipType] == 'automation' && @membershipDetails[:membershipDetails][:active]#or has addon for specific traffic
      @loadedLink = ab_test(:amazonLink, {'affiliteLink' => 95}, {'adminLink' => 5})
    when @membershipDetails&.present? && @membershipDetails[:membershipType] == 'business' && @membershipDetails[:membershipDetails][:active]#or has addon for specific traffic
      @loadedLink = ab_test(:amazonLink, {'affiliteLink' => 80}, {'adminLink' => 20})
    when @membershipDetails&.present? && @membershipDetails[:membershipType] == 'affiliate' && @membershipDetails[:membershipDetails][:active]#or has addon for specific traffic
      @loadedLink = ab_test(:amazonLink, {'affiliteLink' => 60}, {'adminLink' => 40})
    when @membershipDetails&.present? && @membershipDetails[:membershipType] == 'free' && @membershipDetails[:membershipDetails][:active]#or has addon for specific traffic
      @loadedLink = ab_test(:amazonLink, {'affiliteLink' => 50}, {'adminLink' => 50})
    else
      @loadedLink = 'adminLink'
    end
    
    ab_finished(:amazonLink, reset: true)
  end

  # GET /products/1 or /products/1.json
  def show
  	@dataFromApi = User.rainforestProduct(params[:id])
  end

  # GET /products/new
  def new
    @product = Product.new
  end

  # GET /products/1/edit
  def edit
  end

  # POST /products or /products.json
  def create
    @product = Product.new(product_params)

    respond_to do |format|
      if @product.save
        format.html { redirect_to product_url(@product), notice: "Product was successfully created." }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /products/1 or /products/1.json
  def update
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to product_url(@product), notice: "Product was successfully updated." }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/1 or /products/1.json
  def destroy
    @product.destroy

    respond_to do |format|
      format.html { redirect_to products_url, notice: "Product was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = Product.friendly.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def product_params
      params.require(:product).permit(:country, :tags, :asin)
    end
end
