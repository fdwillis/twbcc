class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :timeoutable#, :trackable
  has_many :blogs
  include MediaEmbed::Handler

  ACCEPTEDcountries = {
    'AU' => {
      site: 'amazon.com.au',
      currency: 'aud',
      country: 'Australia', 
    },
    'BE' => {
      site: 'amazon.com.be',
      currency: 'eur',
      country: 'Belgium',
    },
    'BR' => {
      site: 'amazon.com.br',
      currency: 'brl',
      country: 'Brazil',
    },
    'CA' => {
      site: 'amazon.ca',
      currency: 'cad',
      country: 'Canada',
    },
    'CN' => {
      site: 'amazon.cn',
      currency: 'cny',
      country: 'China',
    },
    'FR' => {
      site: 'amazon.fr',
      currency: 'eur',
      country: 'France',
    },
    'DE' => {
      site: 'amazon.de',
      currency: 'eur',
      country: 'Germany',
    },
    'IN' => {
      site: 'amazon.in',
      currency: 'inr',
      country: 'India',
    },
    'IT' => {
      site: 'amazon.it',
      currency: 'eur',
      country: 'Italy',
    },
    'JP' => {
      site: 'amazon.co.jp',
      currency: 'jpy',
      country: 'Japan',
    },
    'MX' => {
      site: 'amazon.com.mx',
      currency: 'mxn',
      country: 'Mexico',
    },
    'NL' => {
      site: 'amazon.nl',
      currency: 'eur',
      country: 'The Netherlands',
    },
    'PL' => {
      site: 'amazon.pl',
      currency: 'pln',
      country: 'Poland',
    },
    'SA' => {
      site: 'amazon.sa',
      currency: 'sar',
      country: 'Saudi Arabia',
    },
    'SG' => {
      site: 'amazon.sg',
      currency: 'sgd',
      country: 'Singapore',
    },
    'ES' => {
      site: 'amazon.es',
      currency: 'eur',
      country: 'Spain',
    },
    'SE' => {
      site: 'amazon.se',
      currency: 'sek',
      country: 'Sweden',
    },
    'AE' => {
      site: 'amazon.ae',
      currency: 'aed',
      country: 'United Arab Emirates',
    },
    'GB' => {
      site: 'amazon.co.uk',
      currency: 'gbp',
      country: 'United Kingdom',
    },
    'US' => {
      site: 'amazon.com',
      currency: 'usd',
      country: 'United States',
    },
  }

  FREEmembership = [ENV['freeMembership']] 
  AFFILIATEmembership = [ENV['affiliateMonthly'],ENV['affiliateAnnual']] 
  BUSINESSmembership = [ENV['businessMonthly'], ENV['businessAnnual']] 
  AUTOMATIONmembership = [ENV['automationMonthly'], ENV['automationAnnual']] 

  def self.renderLink(referredBy, country, asin, affiliateOrAdmin)
    @userFound = referredBy.present? ? User.find_by(uuid: referredBy) : nil
    @profile = @userFound.present? ? Stripe::Customer.retrieve(@userFound.stripeCustomerID) : nil
    @membershipDetails = @userFound.present? ? @userFound.checkMembership : nil

    affiliteLink = "https://www.#{ACCEPTEDcountries[country][:site]}/gp/product/#{asin}?&tag=#{@userFound&.amazonUUID}"
    adminLink =  "https://www.#{ACCEPTEDcountries[country][:site]}/gp/product/#{asin}?&tag=netwerthcard-20"

    #split traffic 95/5
    if affiliateOrAdmin == false
      @loadedLink = adminLink
    elsif affiliateOrAdmin == true
      @loadedLink = affiliteLink
    else
      @loadedLink = adminLink
    end

    @loadedLink
  end

  def media(options = {})
    embed(@url, options)
  end

  def self.rainforestProduct(asin = nil)
    @data = []
    if asin.present?
      res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=product&amazon_domain=amazon.com&asin=#{asin}")
      loadedData = Oj.load(res.body)['product']
      @data << {product: asin, data: loadedData}
    else
      #auto load
      autoSearchProducts.each do |product|
        categoriesLoaded = rainforestSearch(product)
        categoriesLoaded[(rand(0..(categoriesLoaded.count-1)))][:data][0..14]
        asin = categoriesLoaded[(rand(0..(categoriesLoaded.count-1)))][:data][0..14][0]['asin']
        res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=product&amazon_domain=amazon.com&asin=#{asin}")
        loadedData = Oj.load(res.body)['product']
        @data << {product: product, data: loadedData}
        # asin = loadedData['search_results'][rand(1..10)]['asin']
        # link = ENV['amazonUS']

        # "https://www.amazon.com/gp/product/#{loadedData['search_results'][rand(1..10)]['asin']}?&tag=#{ENV['usAmazonTag']}"
      end
    end
    @data
  end

  def self.rainforestSearch(term = nil)
    @data = []
    if term.present?
      res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=search&amazon_domain=amazon.com&search_term=#{term.split.join('+')}")
      loadedData = Oj.load(res.body)['search_results']
      @data << {category: term, data: loadedData}
    else
      #auto load
      autoSearchCategories.each do |category|
        res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=search&amazon_domain=amazon.com&search_term=#{category.split.join('+')}")
        loadedData = Oj.load(res.body)['search_results']
        @data << {category: category, data: loadedData}
        # asin = loadedData['search_results'][rand(1..10)]['asin']
        # link = ENV['amazonUS']

        # "https://www.amazon.com/gp/product/#{loadedData['search_results'][rand(1..10)]['asin']}?&tag=#{ENV['usAmazonTag']}"
      end
    end
    @data
  end

  def self.autoSearchCategories
    approvedCategories = ['Amazon Games',
      'Luxury Beauty',
      'Amazon Explore',
      'Digital Music',
      'Vinyl',
      'Handmade',
      'Digital Videos',
      'cosmetics',
      'luxury kitchen',
      'pet accessories',
      'pet food',
      'baby accessories',
      'garden',
      'home gadgets',
      'oral care',
      'amd',
      'nvidia',
      'fire stick',
      'Amazon Fresh',
      'books',
      'jewelry',
      'hair care',
      'luxury office',
      'silk and satin',
      'luxury bamboo',
      'luxury candles',
      'decorations',
      'landscaping',
      'custom computer',
      'luxury products',
      'car wash',
      'car care',
      'Man cave',
      'birthday',
      'phone protection',
      'luxury bathroom',].shuffle.take(1)
      approvedCategories.map(&:titleize)
    # ['valentines day','independence day', 'halloween', 'easter', 'thanksgiving', 'christmas']
    # save a users last search term
  end

  def self.autoSearchProducts
    approvedProducts = [
      # 'amd',
      # 'corsair',
      # 'TATCHA',
      # 'nvidia',
      # 'think and grow rich',
      # 'lancome',
      # 'BIOSSANCE',
      # 'La Roche-Posay',
      # 'Tata Harper',
      # 'sony',
      # 'xbox',
      'apple',
      # 'sonos',
      # 'Dr. Barbara Sturm',
      # 'otter box'
    ].shuffle.take(1)
    approvedProducts.map(&:titleize)
  end

  def checkMembership
    membershipValid = []
    membershipPlans = [ENV['affiliateMonthly'], ENV['affiliateAnnual'], ENV['businessMonthly'], ENV['businessAnnual'], ENV['automationMonthly'], ENV['automationAnnual']]
    allSubscriptions = Stripe::Subscription.list({customer: stripeCustomerID})['data'].map(&:plan).map(&:id)
    
    membershipPlans.each do |planID|
      if allSubscriptions.include?(planID)
        membershipPlan = Stripe::Subscription.list({customer: stripeCustomerID, price: planID})
        membershipType = AFFILIATEmembership.include?(planID) ? 'affiliate' : BUSINESSmembership.include?(planID) ? 'business': AUTOMATIONmembership.include?(planID) ? 'automation': FREEmembership.include?(planID) ? 'free' : nil
        membershipValid << {membershipDetails: membershipPlan['data'][0]['items']['data'][0]['plan']}.merge({membershipType: membershipType})
      end
    end

    membershipValid[0]
  end

  def customer?
    customerAccess.include?(accessPin)
  end

  def connectAccount?
    connectAccountAccess.include?(accessPin)
  end

  def trustee?
    trusteeAccess.include?(accessPin)     
  end

  def manager?
    managerAccess.include?(accessPin)
  end

  def admin?
    adminAccess.include?(accessPin)     
  end

  private
  def connectAccountAccess
    return ['connectAccount']
  end

  def customerAccess
    return ['customer']
  end

  def trusteeAccess
    return ['trustee']
  end

  def managerAccess
    return ['manager', 'trustee', 'admin']
  end
  
  def adminAccess
    return ['admin' , 'trustee']
  end
end
