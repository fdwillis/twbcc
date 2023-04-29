json.extract! blog, :id, :title, :body, :asins, :users_id, :created_at, :updated_at
json.url blog_url(blog, format: :json)
