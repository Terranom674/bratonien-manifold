# frozen_string_literal: true

class AccountMailer < ApplicationMailer
  def email_confirmation(user)
    @email_confirmation_url = @api_routes.email_confirmation_url_for(user)
    @user = user
    mail(to: @user.email, subject: "E-Mail-Adresse bestätigen")
  end

  def reset_password(user)
    @user = user
    mail(to: @user.email, subject: "Zurücksetzen des Passworts angefordert")
  end

  def password_change_notification(user)
    @user = user
    mail(to: @user.email, subject: "Dein Passwort wurde zurückgesetzt")
  end

  def welcome(user, created_by_admin: false)
    @email_confirmation_url = @api_routes.email_confirmation_url_for(user)
    @user = user
    @created_by_admin = created_by_admin
    mail(to: @user.email, subject: "Willkommen bei Manifold!")
  end
end
