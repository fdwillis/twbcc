class BlogsController < ApplicationController
  before_action :set_blog, only: %i[ show edit update destroy ]
  before_action :authenticate_user!, except: %i[index show]
  before_action :checkAccess, only: %i[ new update ]

  # GET /blogs or /blogs.json
  def index
    @featured = []
    @blogs = Blog.paginate(page: params[:page], per_page: 8)
    Blog.all.map{|blog| blog['tags'].split(',').include?('featured') ? @featured << blog : next}
  end

  # GET /blogs/1 or /blogs/1.json
  def show
    #analytics
    ahoy.track "Blog Page Visit", title: @blog.title, user: params['referredBy'].present? ? User.find_by(uuid: params['referredBy']).uuid : current_user.present? ? current_user.uuid : 'admin'
  end

  # GET /blogs/new
  def new
    @blog = Blog.new
  end

  # GET /blogs/1/edit
  def edit
  end

  # POST /blogs or /blogs.json
  def create
    images = []
    @blog = current_user.blogs.create!(blog_params)
    if params['attachment'].present?
      params['attachment']['file'].each_with_index do |image, indx|
        Cloudinary::Uploader.upload(image.tempfile, :use_filename => true, :folder => "blog/#{current_user.uuid}", :public_id => "#{blog_params['title'].parameterize(separator: '-')}-#{indx}")
        images.push("https://res.cloudinary.com/dulizdfij/image/upload/blog/#{current_user.uuid}/#{@blog.title.parameterize(separator: '-')}-#{indx}.jpg")
      end
    end

    @blog.update(images: images.join(","))

    respond_to do |format|
      if @blog.save
        format.html { redirect_to blog_url(@blog), notice: "Blog was successfully created." }
        format.json { render :show, status: :created, location: @blog }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @blog.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /blogs/1 or /blogs/1.json
  def update
    respond_to do |format|
      images = []
      if params['attachment'].present?
        params['attachment']['file'].each_with_index do |image, indx|
          Cloudinary::Uploader.upload(image.tempfile, :use_filename => true, :folder => "blog/#{current_user.uuid}", :public_id => "#{blog_params['title'].parameterize(separator: '-')}-#{indx}")
          images.push("https://res.cloudinary.com/dulizdfij/image/upload/blog/#{current_user.uuid}/#{@blog.title.parameterize(separator: '-')}-#{indx}.jpg")
        end
      end

      if images.present?
        @blog.update(images: images.join(","))
      end
      
      if @blog.update(blog_params)
        format.html { redirect_to blog_url(@blog), notice: "Blog was successfully updated." }
        format.json { render :show, status: :ok, location: @blog }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @blog.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /blogs/1 or /blogs/1.json
  def destroy
    @blog.destroy

    respond_to do |format|
      format.html { redirect_to blogs_url, notice: "Blog was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_blog
      @blog = Blog.friendly.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def blog_params
      params.require(:blog).permit(:title, :body, :asins, :user_id, :images, :tags, :country).reject{|_, v| v.blank?}
    end
    def checkAccess
      unless current_user&.admin? || (current_user&.present? && current_user&.checkMembership[:membershipType] == 'business' && current_user&.checkMembership[:membershipDetails][:active] == true) || (current_user&.present? && current_user&.checkMembership[:membershipType] == 'automation'&& current_user&.checkMembership[:membershipDetails][:active] == true)
        flash[:error] = "No Access"
        redirect_to root_path
      end
    end
end
