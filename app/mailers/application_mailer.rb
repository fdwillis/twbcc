class ApplicationMailer < ActionMailer::Base
  default from: 'team@oarlin.com'
  layout 'mailer'

  def sessionLink(sessionID)
    stripeSessionData = Stripe::Checkout::Session.retrieve(sessionID)
    stripeCustomerX = Stripe::Customer.retrieve(stripeSessionData['customer'])
    link = "https://card.twbcc.com/new-password-set?session=#{sessionID}"

    mail(
      to: stripeCustomerX['email'],
      subject: 'Welcome To The Wisconsin Black Chamber of Commerce',
      body: "Thank you for joining, here is your link to complete your setup: #{link}"
    )
  end
end
