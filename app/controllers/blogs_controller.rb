class BlogsController < ApplicationController
  before_action :set_blog, only: %i[ show edit update destroy ]
  before_action :authenticate_user!, except: %i[index show]
  before_action :checkAccess, only: %i[ new update ]

  # GET /blogs or /blogs.json
  def index
    @featured = []
    @blogs = Blog.paginate(page: params['page'], per_page: 6)
    @blogs.map{|blog| blog['tags'].split(',').reject(&:blank?).include?('featured') ? @featured << blog : nil}
    ahoy.track "Blog Page Results", previousPage: request.referrer, currentPage: params['page']
  end

  # GET /blogs/1 or /blogs/1.json
  def show
    #analytics
    ahoy.track "Blog Page Visit", previousPage: request.referrer, title: @blog.title, referredBy: params['referredBy'].present? ? params['referredBy'] : current_user&.present? ? current_user&.uuid : ENV['usAmazonTag'], uuid: @blog&.user&.uuid
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
        images.push("https://res.cloudinary.com/dulizdfij/image/upload/blog/#{current_user.uuid.downcase}/#{@blog.title.parameterize(separator: '-')}-#{indx}.jpg")
      end
    end

    @blog.update(images: images.join(","))

    respond_to do |format|
      if @blog.save
        format.html { redirect_to "#{blog_url(@blog.title.parameterize(separator: '-'))}/?&referredBy=#{current_user&.present? ? current_user&.uuid : params['referredBy']}", notice: "Blog was successfully created." }
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
        if @blog.images.split(',').size > 0
          @blog.images.split(',').each_with_index do |img, indx|
            result = Cloudinary::Api.delete_resources(["#{@blog['title'].parameterize(separator: '-')}-#{indx}"])
          end
        end

        params['attachment']['file'].each_with_index do |image, indx|

          Cloudinary::Uploader.upload(image.tempfile, :use_filename => true, :folder => "blog/#{current_user.uuid}", :public_id => "#{blog_params['title'].parameterize(separator: '-')}-#{indx}")
          images.push("https://res.cloudinary.com/dulizdfij/image/upload/blog/#{current_user.uuid}/#{@blog.title.parameterize(separator: '-')}-#{indx}.jpg")

        end
      end

      if images.present?
        @blog.update(images: images.join(","))
      end
      
      if @blog.update(blog_params)
        format.html { redirect_to "#{blog_url(@blog)}/?&referredBy=#{current_user&.present? ? current_user&.uuid : params['referredBy']}", notice: "Blog was successfully updated." }
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
      format.html { redirect_to "#{blogs_url}/?&referredBy=#{current_user&.present? ? current_user&.uuid : params['referredBy']}", notice: "Blog was successfully destroyed." }
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
      unless current_user&.admin? || (current_user&.present? && current_user&.checkMembership[:membershipType] == 'business' && current_user&.checkMembership[:membershipDetails][0]['status'] == 'active') || (current_user&.present? && current_user&.checkMembership[:membershipType] == 'automation'&& current_user&.checkMembership[:membershipDetails][0]['status'] == 'active')
        flash[:error] = "Business or Automation Plan Required"
        redirect_to membership_path
      end
    end
end
