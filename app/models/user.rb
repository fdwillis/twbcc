require 'will_paginate/array'
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :timeoutable#, :trackable
  has_many :blogs
  has_many :trades
  has_many :take_profits
  
  include MediaEmbed::Handler

  ACCEPTEDcountries = {
    #sprint2 check magic team from these countries
    'au' => {
      site: 'amazon.com.au',
      currency: 'aud',
      country: 'Australia', 
    },
    'be' => {
      site: 'amazon.com.be',
      currency: 'eur',
      country: 'Belgium',
    },
    'ca' => {
      site: 'amazon.ca',
      currency: 'cad',
      country: 'Canada',
    },
    'fr' => {
      site: 'amazon.fr',
      currency: 'eur',
      country: 'France',
    },
    'de' => {
      site: 'amazon.de',
      currency: 'eur',
      country: 'Germany',
    },
    'it' => {
      site: 'amazon.it',
      currency: 'eur',
      country: 'Italy',
    },
    'jp' => {
      site: 'amazon.co.jp',
      currency: 'jpy',
      country: 'Japan',
    },
    'mx' => {
      site: 'amazon.com.mx',
      currency: 'mxn',
      country: 'Mexico',
    },
    'nl' => {
      site: 'amazon.nl',
      currency: 'eur',
      country: 'Netherlands',
    },
    'pl' => {
      site: 'amazon.pl',
      currency: 'pln',
      country: 'Poland',
    },
    'sg' => {
      site: 'amazon.sg',
      currency: 'sgd',
      country: 'Singapore',
    },
    'es' => {
      site: 'amazon.es',
      currency: 'eur',
      country: 'Spain',
    },
    'se' => {
      site: 'amazon.se',
      currency: 'sek',
      country: 'Sweden',
    },
    'ae' => {
      site: 'amazon.ae',
      currency: 'aed',
      country: 'United Arab Emirates',
    },
    'gb' => {
      site: 'amazon.co.uk',
      currency: 'gbp',
      country: 'United Kingdom',
    },
    'us' => {
      site: 'amazon.com',
      currency: 'usd',
      country: 'United States',
    },
  }

  FREEmembership = [ENV['freeMembership']] 
  TRADERmembership = [ENV['selfTradingMonthlyMembership'],ENV['selfTradingAnnualMembership'],ENV['autoTradingMonthlyMembership'],ENV['autoTradingAnnualMembership']] 
  AFFILIATEmembership = [ENV['affiliateMonthly'],ENV['affiliateAnnual']] 
  BUSINESSmembership = [ENV['businessMonthly'], ENV['businessAnnual']] 
  AUTOMATIONmembership = [ENV['automationMonthly'], ENV['automationAnnual']] 

  def self.renderLink(referredBy, country, asin, current_user = nil)
    @userFound = referredBy.present? ? User.find_by(uuid: referredBy) : nil
    @profile = @userFound.present? ? Stripe::Customer.retrieve(@userFound.stripeCustomerID) : nil
    @membershipDetails = @userFound.present? ? @userFound.checkMembership : nil
    #account for current user
    affiliteLink = "https://www.#{ACCEPTEDcountries[country.downcase][:site]}/dp/product/#{asin.upcase}?&tag=#{@userFound&.amazonUUID}"
    adminLink =  "https://www.#{ACCEPTEDcountries[country.downcase][:site]}/dp/product/#{asin.upcase}?&tag=#{ENV['usAmazonTag']}"
    #split traffic 95/5
    if @membershipDetails.present? && @membershipDetails[:membershipDetails][0]['status'] == 'active'
      if current_user&.referredBy&.split(',').present? && current_user&.referredBy&.split(',').reject(&:blank?).present?
        affiliteLink = "https://www.#{ACCEPTEDcountries[country.downcase][:site]}/dp/product/#{asin.upcase}?&tag=#{User.find_by(uuid: current_user&.referredBy)&.amazonUUID}"
        @loadedLink = affiliteLink
      elsif current_user.nil?
        @loadedLink = affiliteLink
      else
        @loadedLink = adminLink
      end

    else 
      @loadedLink = adminLink
    end

    @loadedLink
  end

  def media(options = {})
    embed(@url, options)
  end

  def self.rainforestProduct(asin = nil, search_alias = nil, country = nil )
    @validResponse = []
    if asin.present?
      res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=product&amazon_domain=#{ACCEPTEDcountries[country][:site]}&asin=#{asin}")
    else
      #auto load
      res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=product&amazon_domain=#{ACCEPTEDcountries[country][:site]}&asin=#{asin}&search_alias=#{search_alias}")
    end
    loadedData = Oj.load(res.body)['product']
    @validResponse << {product: asin, data: loadedData}

    response = @validResponse.first[:data]

    if response&.present?
      {
        'asin'=> asin,
        # 'description'=> response['description'],
        'country'=> country.upcase,
        'tags'=> response['keywords_list'].present? ? response['keywords_list'][0..response['keywords_list'].size].join(',') : nil,
        'keywords' => response['keywords_list'].present? ? response['keywords_list'][0..9].shuffle : nil,
        'rating' => response['rating'].present? ? response['rating'] : nil ,
        'reviews' => response['top_reviews'].present? ? response['top_reviews'].shuffle : nil,
        'brand' => response['brand'].present? ? response['brand'] : nil , 
        'images' => response['main_image']['link'],
      }
    else
      {}
    end
  end

  def self.rainforestSearch(term = nil, category = nil, country = nil)
    @data = []

    if category&.present?
      res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=search&amazon_domain=#{ACCEPTEDcountries[country][:site]}&search_term=#{term.split.join('+')}&categories=#{category}")
    else
      res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=search&amazon_domain=#{ACCEPTEDcountries[country][:site]}&search_term=#{term.split.join('+')}")
    end
      
    loadedData = Oj.load(res.body)['search_results']
    @data << {category: term, data: loadedData}
    @data[0][:data]
  end

  def self.autoSearchCategories
    # eps gem for text predictions #sprint2
    approvedCategories = {
      0 => {
        # category: 'His & Her Night Out',
        category: 'Amazon Games',
        description: 'amazon games',
        tags: ['self care', 'self love', 'facial', 'beauty', 'cosmetics'],
        featured: true,
        published: true,
        image: [
          'https://pbs.twimg.com/profile_images/1542913048926556162/ptySop9e_400x400.jpg',
          'https://pbs.twimg.com/profile_images/1542913048926556162/ptySop9e_400x400.jpg',
        ],
        # brand: [
        #   {
        #     title: ,
        #     tags: ,
        #     countries: magic assistant will swap ending URL to find where products are available -> checkbox field,
        #     images: [
        #     ],
        #   }
        # ],

      },
      1 => {
        category: 'Luxury Beauty',
        description: 'Luxury Brands Like Mario Badescu, Tatcha, Pureology & More',
        tags: ['self care', 'self love', 'facial', 'beauty', 'cosmetics'],
        featured: true,
        published: true,
        image: [
          'https://images.squarespace-cdn.com/content/v1/5b11542985ede1725e58d543/1645560337277-1Z86HHV2CS7WXFDMH4CF/Pureology-Smooth+Perfection-Shampoo.jpg?format=300w',
          'https://img.grouponcdn.com/stores/3ff1nFbyHFWqg981Ekfns8mLRJRf/storespi29979734-5939x3563/v1/sc600x600.jpg',
          'https://www.pureology.com/on/demandware.static/-/Sites-ppd-pureology-master-catalog/default/dwf0393240/pdp/PPDPURHydrateDuo/Pureology-Hydrate-Shampoo-Conditioner-Duo-Retail.png',
          'https://pyxis.nymag.com/v1/imgs/32e/7be/632c500b7d59f478f5892606d333b2147c-mario-badescu-lede.rsocial.w1200.jpg',
          'https://m.media-amazon.com/images/I/81KBMk-i+FL._AC_SL1500_.jpg',
          'https://m.media-amazon.com/images/I/81EG0Mqv6mL._AC_UF1000,1000_QL80_.jpg',
          'https://m.media-amazon.com/images/I/81i7HXhZSmL._AC_UF1000,1000_QL80_.jpg',
        ],
        # brand: [
        #   {
        #     title: Mario Badescu,
        #     tags: ['self care', 'self love', 'facial', 'beauty', 'cosmetics'],
        #     countries: ['us', 'es', 'de'],
        #     images: [
                # 'asd.com/'
        #     ],
        #   }
        # ],

      },
      # 
      # Tatcha
      # Pureology





      # 'Luxury Beauty' => {
      #   description: '',
      #   image: '',

      # },
      # 'Amazon Explore' => {
      #   description: '',
      #   image: '',

      # },
      # 'Digital Music' => {
      #   description: '',
      #   image: '',

      # },
      # 'Vinyl' => {
      #   description: '',
      #   image: '',

      # },
      # 'Handmade' => {
      #   description: '',
      #   image: '',

      # },
      # 'Digital Videos' => {
      #   description: '',
      #   image: '',

      # },
      # 'cosmetics' => {
      #   description: '',
      #   image: '',

      # },
      # 'luxury kitchen' => {
      #   description: '',
      #   image: '',

      # },
      # 'pet accessories',
      # 'pet food',
      # 'baby accessories',
      # 'garden',
      # 'home gadgets',
      # 'oral care',
      # 'amd',
      # 'nvidia',
      # 'fire stick',
      # 'Amazon Fresh',
      # 'jewelry',
      # 'hair care',
      # 'luxury office',
      # 'silk and satin',
      # 'luxury bamboo',
      # 'luxury candles',
      # 'decorations',
      # 'landscaping',
      # 'custom computer',
      # 'luxury products',
      # 'car care',
      # 'Man cave',
      # 'birthday',
      # 'phone protection',
      # 'luxury bathroom',
      # 'For Her',
      # 'For Him',
    }
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
    membershipPlans = [ENV['autoTradingMonthlyMembership'], ENV['autoTradingAnnualMembership'],ENV['selfTradingAnnualMembership'], ENV['selfTradingMonthlyMembership'],ENV['affiliateMonthly'], ENV['affiliateAnnual'], ENV['businessMonthly'], ENV['businessAnnual'], ENV['automationMonthly'], ENV['automationAnnual']]
    allSubscriptions = Stripe::Subscription.list({customer: stripeCustomerID})['data'].map(&:items).map(&:data).flatten.map(&:plan).map(&:id)
    
    membershipPlans.each do |planID|
      case true
      when allSubscriptions.include?(planID)
        membershipPlan = Stripe::Subscription.list({customer: stripeCustomerID, price: planID})['data'][0]
        membershipType = TRADERmembership.include?(planID) ? 'trader' : AFFILIATEmembership.include?(planID) ? 'affiliate' : BUSINESSmembership.include?(planID) ? 'business': AUTOMATIONmembership.include?(planID) ? 'automation': FREEmembership.include?(planID) ? 'free' : 'free'
        if membershipPlan['status'] == 'active' && membershipPlan['pause_collection'] == nil
          membershipValid << {membershipDetails: membershipPlan, membershipType: membershipType}
        end
      end
    end

    membershipValid.present? ? membershipValid : [{membershipType: 'free', membershipDetails: {0=>{'status' => 'active', 'interval' => 'N/A'}}}]

    if Oj.load(ENV['adminUUID']).include?(self.uuid)
      membershipValid.present? ? self.update(accessPin:"admin,#{ membershipValid.map{|d| d[:membershipType]}.join(',')}") : nil
    else
      membershipValid.present? ? self.update(accessPin: membershipValid.map{|d| d[:membershipType]}.join(',')) : nil
    end

    membershipValid
  end

  def customer?
    checkMembership
    accessPin.split(',').include?('customer')
  end

  def trader?
    checkMembership
    accessPin.split(',').include?('trader')
  end

  def connectAccount?
    checkMembership
    accessPin.split(',').include?('connectAccount') || accessPin.split(',').include?('affilite') || accessPin.split(',').include?('business') || accessPin.split(',').include?('automation')
  end

  def trustee?
    checkMembership
    accessPin.split(',').include?('trustee')
  end

  def manager?
    checkMembership
    accessPin.split(',').include?('manager')
  end

  def admin?
    checkMembership
    accessPin.split(',').include?('admin')
  end

  private
end
