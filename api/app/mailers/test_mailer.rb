# frozen_string_literal: true

class TestMailer < ApplicationMailer
  def test(user)
    @user = user
    message = mail(to: @user.email, subject: "Manifold-E-Mail-System funktioniert")
    message.raise_delivery_errors = true
    message
  end
end
