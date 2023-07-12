class Kraken < ApplicationRecord
  def self.get_kraken_signature(uri_path, api_nonce, _api_sec, api_post, secretKey)
    api_sha256 = OpenSSL::Digest.new('sha256').digest("#{api_nonce}#{api_post}")
    api_hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha512'), Base64.decode64(secretKey), "#{uri_path}#{api_sha256}")
    Base64.strict_encode64(api_hmac)
  end

  def self.request(uri_path, orderParams = {}, apiKey, secretKey)
    api_nonce = (Time.now.to_f * 1000).to_i.to_s
    post_data = orderParams.present? ? orderParams.map { |key, value| "#{key}=#{value}" }.join('&') : nil
    api_post = (orderParams.present? ? "nonce=#{api_nonce}&#{post_data}" : "nonce=#{api_nonce}")
    api_signature = get_kraken_signature(uri_path, api_nonce, apiKey, api_post, secretKey)

    headers = {
      'API-Key' => apiKey,
      'API-Sign' => api_signature
    }

    uri = URI('https://api.kraken.com' + uri_path)
    req = Net::HTTP::Post.new(uri.path, headers)
    orderParams.present? ? req.set_form_data({ 'nonce' => api_nonce }.merge(orderParams)) : req.set_form_data({ 'nonce' => api_nonce })
    req.body = CGI.unescape(req.body)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(req)
    sleep 1
    Oj.load(response.body)
  end

  def self.krakenDeposits(apiKey, secretKey)
    routeToKraken = '/0/private/DepositStatus'
    request(routeToKraken, nil, apiKey, secretKey)
  end

  def self.krakenBalance(apiKey, secretKey)
    routeToKraken = '/0/private/Balance'
    request(routeToKraken, nil, apiKey, secretKey)
  end

  def self.pendingTrades(apiKey, secretKey)
    routeToKraken = '/0/private/OpenOrders'
    orderParams = {}
    requestK = request(routeToKraken, orderParams, apiKey, secretKey)['result']['open']
  end

  def self.tradeBalance(symbol, apiKey, secretKey)
    routeToKraken = '/0/private/TradeBalance'
    orderParams = {
      'asset' => symbol
    }

    requestK = request(routeToKraken, orderParams, apiKey, secretKey)
  end

  def self.tickerInfo(tvData, apiKey, secretKey)
    routeToKraken = '/0/public/Ticker'
    orderParams = {
      'pair' => tvData['ticker']
    }

    requestK = request(routeToKraken, orderParams, apiKey, secretKey)
  end

  def self.assetInfo(tvData, apiKey, secretKey)
    routeToKraken = '/0/public/Assets'
    orderParams = {
      'asset' => tvData['ticker']
    }

    requestK = request(routeToKraken, orderParams, apiKey, secretKey)
  end

  def self.publicPair(tvData, apiKey, secretKey)
    routeToKraken = '/0/public/AssetPairs'
    orderParams = {
      'pair' => tvData['ticker']
    }

    requestK = request(routeToKraken, orderParams, apiKey, secretKey)
  end

  def self.orderInfo(orderID, apiKey, secretKey)
    routeToKraken = '/0/private/QueryOrders'
    orderParams = {
      'txid' => orderID,
      'trades' => true
    }
    request(routeToKraken, orderParams, apiKey, secretKey)
  end

  def self.newTrail(tvData, tradeInfo, apiKey, secretKey, tradeX)
    traderFound = User.find_by(krakenLiveAPI: apiKey)
    if traderFound&.reduceBy.present? && traderFound&.reduceBy != 100
      routeToKraken = '/0/private/AddOrder'

      orderParams = {
        'pair' => tradeInfo['descr']['pair'],
        'ordertype' => 'stop-loss',
        'type' => tvData['direction'],
        'price' => (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
        # "price2" 		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
        'volume' => (tradeInfo['vol'].to_f * (0.01 * traderFound&.reduceBy)) > 0.0001 ? format('%.10f', (tradeInfo['vol'].to_f * (0.01 * traderFound&.reduceBy))) : '0.0001'
      }
      sleep 1
      requestProfit = request(routeToKraken, orderParams, apiKey, secretKey)
    elsif traderFound&.reduceBy.present? && traderFound&.reduceBy == 100
      routeToKraken1 = '/0/private/AddOrder'

      orderParams1 = {
        'pair' => tradeInfo['descr']['pair'],
        'ordertype' => 'stop-loss',
        'type' => tvData['direction'],
        'price' => (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
        # "price2" 		=> (tvData['type'] == 'sellStop' ? (tvData['currentPrice'].to_f + (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1) : (tvData['currentPrice'].to_f - (tvData['currentPrice'].to_f * (0.01 * tvData['trail'].to_f))).round(1)).to_s,
        'volume' => tradeInfo['vol']
      }
      sleep 1
      requestProfit = request(routeToKraken1, orderParams1, apiKey, secretKey)

    end
    puts "\n-- Trail Request #{requestProfit} --\n"

    if !requestProfit.empty? && requestProfit['result']['txid'].present?
      tradeX.take_profits.create!(traderID: tvData['traderID'], uuid: requestProfit['result']['txid'][0], status: 'open', direction: tvData['direction'], broker: tvData['broker'], user_id: User.find_by(krakenLiveAPI: apiKey).id, cost: requestProfit['result']['cost'].to_f)
      requestProfit
    else
      []
    end
  end

  def self.krakenRisk(tvData, apiKey, secretKey)
    traderFound = User.find_by(krakenLiveAPI: apiKey)
    # hard coded min for bitcoin

    currentPrice = tvData['currentPrice'].to_f

    requestK = krakenBalance(apiKey, secretKey)

    accountBalance = requestK['result']['ZUSD'].to_f

    ((traderFound&.perEntry * 0.01) * accountBalance).to_f > 3 ? ((traderFound&.perEntry * 0.01) * accountBalance / currentPrice).to_f : (3 / currentPrice).to_f
  end
end
