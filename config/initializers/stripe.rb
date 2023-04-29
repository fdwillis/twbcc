if Rails.env.development? || Rails.env.test?
  Rails.configuration.stripe = {
    :publishable_key => ENV['stripeTestPublish'],
    :secret_key      => ENV['stripeTestSecret']
  }

  
elsif Rails.env.production?
  Rails.configuration.stripe = {
    :publishable_key => ENV['stripeLivePublish'],
    :secret_key      => ENV['stripeLiveSecret']
  }
end  

Stripe.api_key = Rails.configuration.stripe[:secret_key]