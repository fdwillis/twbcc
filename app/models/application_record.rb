class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  # Generate the Kraken API signature

  #kraken

  def self.get_kraken_signature(uri_path, api_nonce, api_sec, api_post)
    api_sha256 = OpenSSL::Digest.new('sha256').digest("#{api_nonce}#{api_post}")
    api_hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha512'), Base64.decode64(ENV['krakenTestSecret']), "#{uri_path}#{api_sha256}")
    Base64.strict_encode64(api_hmac)
  end

  # Attaches auth headers and returns results of a POST request
  def self.krakenRequest(uri_path, orderParams = {})
    api_nonce = (Time.now.to_f * 1000).to_i.to_s
    post_data = orderParams.map { |key, value| "#{key}=#{value}" }.join('&')
    api_post = post_data.present? ? "nonce=#{api_nonce}&#{post_data}" : "nonce=#{api_nonce}"
    api_signature = get_kraken_signature(uri_path, api_nonce, ENV['krakenTestSecret'], api_post)
    
    headers = {
      "API-Key" => ENV['krakenTestAPI'],
      "API-Sign" => api_signature
    }

    uri = URI("https://api.kraken.com" + uri_path)
    req = Net::HTTP::Post.new(uri.path, headers)
    req.set_form_data({ "nonce" => api_nonce }.merge(orderParams))
    sleep 1

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(req)
    Oj.load(response.body)
    sleep 1
  end

  #oanda
end
