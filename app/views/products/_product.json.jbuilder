json.extract! product, :id, :country, :tags, :asin, :created_at, :updated_at
json.url product_url(product, format: :json)
