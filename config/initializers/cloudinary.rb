Cloudinary.config do |config|
  config.cloud_name = ENV['cloudinaryNAME']
  config.api_key = ENV['cloudinaryKEY']
  config.api_secret = ENV['cloudinarySECRET']
  config.secure = true
end
