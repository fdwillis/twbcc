require 'will_paginate/array'
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :timeoutable # , :trackable

  include MediaEmbed::Handler

  BASICmembership = [ENV['basicMembership']].freeze
  BIZmembership = [ENV['bizMembership']].freeze
  EXECmembership = [ENV['executiveMembership']].freeze
  EQUITYmembership = [ENV['equityMembership']].freeze



  def checkMembership
    membershipValid = []
    membershipPlans = User::BASICmembership+User::BIZmembership+User::EXECmembership+User::EQUITYmembership
    allSubscriptions = Stripe::Subscription.list({ customer: stripeCustomerID })['data'].map(&:items).map(&:data).flatten.map(&:plan).map(&:id)

    #check for payment of membership
    # when checking for addOns us addOnPaid or addOnPending
    membershipPlans.each do |planID|
      case true
      when allSubscriptions.include?(planID)
        membershipPlans = Stripe::Subscription.list({ customer: stripeCustomerID, price: planID })['data']
        

        membershipPlans.each do |planX|
          membershipType = BASICmembership.include?(planID) ? 'member,basic' : BIZmembership.include?(planID) ? 'member,biz' : EXECmembership.include?(planID) ? 'member,exec' : EQUITYmembership.include?(planID) ? 'member,equity' : nil
                           
          membershipValid << { membershipDetails: planX, membershipType: self.uuid == 'd57307d7' ? membershipType + ',admin' : membershipType }
        end

      else
        # membershipValid << { membershipDetails: membershipPlan, membershipType: membershipType }
      end
    end

    self.update(accessPin: membershipValid.map { |d| d[:membershipType] }.uniq.join(','))

    membershipValid
  end


  def self.twilioText(number, message)
    if ENV['stripeLivePublish'].include?("pk_live_") && Rails.env.production? && number
      account_sid = ENV['twilioAccounSID']
      auth_token = ENV['twilioAuthToken']
      client = Twilio::REST::Client.new(account_sid, auth_token)
      
      from = '+18335152633'
      to = number

      client.messages.create(
        from: from,
        to: to,
        body: message
      )
    else
      :testing_mode
    end
  end

  def media(options = {})
    embed(@url, options)
  end

  def currencyBase
    ISO3166::Country[amazonCountry.downcase].currency_code
  end

  def biz?
    accessPin.split(',').include?('biz')
  end

  def basic?
    accessPin.split(',').include?('basic')
  end

  def exec?
    accessPin.split(',').include?('exec')
  end

  def member?
    accessPin.split(',').include?('member')
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

  def self.stripeAmount(string)
    converted = (string.gsub(/[^0-9]/i, '').to_i)

    if string.include?(".")
      dollars = string.split(".")[0]
      cents = string.split(".")[1]

      if cents.length == 2
        stripe_amount = "#{dollars}#{cents}"
      else
        if cents === "0"
          stripe_amount = ("#{dollars}00")
        else
          stripe_amount = ("#{dollars}#{cents.to_i * 10}")
        end
      end

      return stripe_amount
    else
      stripe_amount = converted * 100
      return stripe_amount
    end
  end
end
