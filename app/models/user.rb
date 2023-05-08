require 'will_paginate/array'
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :timeoutable#, :trackable
  has_many :blogs
  include MediaEmbed::Handler

  ACCEPTEDcountries = {
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
  AFFILIATEmembership = [ENV['affiliateMonthly'],ENV['affiliateAnnual']] 
  BUSINESSmembership = [ENV['businessMonthly'], ENV['businessAnnual']] 
  AUTOMATIONmembership = [ENV['automationMonthly'], ENV['automationAnnual']] 

  def self.renderLink(referredBy, country, asin, affiliateOrAdmin)
    @userFound = referredBy.present? ? User.find_by(uuid: referredBy) : nil
    @profile = @userFound.present? ? Stripe::Customer.retrieve(@userFound.stripeCustomerID) : nil
    @membershipDetails = @userFound.present? ? @userFound.checkMembership : nil

    affiliteLink = "https://www.#{ACCEPTEDcountries[country][:site]}/dp/product/#{asin}?&tag=#{@userFound&.amazonUUID}"
    adminLink =  "https://www.#{ACCEPTEDcountries[country][:site]}/dp/product/#{asin}?&tag=netwerthcard-20"

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

  def self.rainforestProduct(asin = nil, country)
    @data = []
    if asin.present?
      res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=product&amazon_domain=#{ACCEPTEDcountries[country][:site]}&asin=#{asin}")
      loadedData = Oj.load(res.body)['product']
      @data << {product: asin, data: loadedData}
    else
      #auto load
      autoSearchProducts.each do |product|
        categoriesLoaded = rainforestSearch(product, country)
        categoriesLoaded[(rand(0..(categoriesLoaded.count-1)))][:data][0..14]
        asin = categoriesLoaded[(rand(0..(categoriesLoaded.count-1)))][:data][0..14][0]['asin']
        res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=product&amazon_domain=#{ACCEPTEDcountries[country][:site]}&asin=#{asin}")
        loadedData = Oj.load(res.body)['product']
        @data << {product: product, data: loadedData}
        # asin = loadedData['search_results'][rand(1..10)]['asin']
        # link = ENV['amazonUS']

        # "https://www.amazon.com/dp/#{loadedData['search_results'][rand(1..10)]['asin']}&tag=#{ENV['usAmazonTag']}"
      end
    end

    @data
    {'asin'=> asin, 'country'=> 'US', 'tags'=> 'RAINFOREST CALL'}
  end

  def self.rainforestSearch(term = nil, country)
    @data = []
    if term.present?
      res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=search&amazon_domain=#{ACCEPTEDcountries[country][:site]}&search_term=#{term.split.join('+')}")
      loadedData = Oj.load(res.body)['search_results']
      @data << {category: term, data: loadedData}
    else
      #auto load
      autoSearchCategories.each do |category|
        res = Curl.get("https://api.rainforestapi.com/request?api_key=#{ENV['rainforestAPI']}&type=search&amazon_domain=#{ACCEPTEDcountries[country][:site]}&search_term=#{category.split.join('+')}")
        loadedData = Oj.load(res.body)['search_results']
        @data << {category: category, data: loadedData}
        # return country in response to display flag
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
      case true
      when allSubscriptions.include?(planID)
        membershipPlan = Stripe::Subscription.list({customer: stripeCustomerID, price: planID})
        membershipType = AFFILIATEmembership.include?(planID) ? 'affiliate' : BUSINESSmembership.include?(planID) ? 'business': AUTOMATIONmembership.include?(planID) ? 'automation': FREEmembership.include?(planID) ? 'free' : 'free'
        membershipValid << {membershipDetails: membershipPlan['data'][0]['items']['data'][0]['plan']}.merge({membershipType: membershipType})
      end
    end

    membershipValid.present? ? membershipValid[0] : {membershipDetails: {active: true, 'interval' => 'N/A'},membershipType: 'free'}
  end

  def customer?
    accessPin.split(',').include?('customer')
  end

  def connectAccount?
    accessPin.split(',').include?('connectAccount')
  end

  def trustee?
    accessPin.split(',').include?('trustee')
  end

  def manager?
    accessPin.split(',').include?('manager')
  end

  def admin?
    accessPin.split(',').include?('admin')
  end

  private
end
