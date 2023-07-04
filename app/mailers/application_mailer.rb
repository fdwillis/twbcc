class ApplicationMailer < ActionMailer::Base
  default from: 'team@oarlin.com'
  layout 'mailer'

  def sessionLink(sessionID)
    stripeSessionData = Stripe::Checkout::Session.retrieve(sessionID)
    paidStripeCustomer = Stripe::Customer.retrieve(stripeSessionData['customer'])
    loadedAffililate = paidStripeCustomer['metadata']['referredBy'].present? ? paidStripeCustomer['metadata']['referredBy'].split(',').reject(&:blank?) : nil
    link = loadedAffililate.present? ? "https://app.oarlin.com/trading?session=#{sessionID}&referredBy=#{loadedAffililate}" : "https://app.oarlin.com/trading?session=#{sessionID}"

    mail(
      to: paidStripeCustomer['email'],
      subject: 'Welcome To Oarlin',
      body: "Thank you for joining Oarlin. Here is your link to complete your account setup: #{link}"
    )
  end
end
