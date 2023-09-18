require 'will_paginate/array'
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :timeoutable # , :trackable

  include MediaEmbed::Handler


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

  def business?
    accessPin.split(',').include?('business')
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
