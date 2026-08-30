# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  before_action :hide_valediction

  def digest(user, frequency, digest_events)
    user_assignment user
    @frequency = frequency
    @projects, @annotations_and_comments =
      digest_events.values_at :projects, :annotations_and_comments
    frequency_label = { daily: "Tägliche", weekly: "Wöchentliche" }.fetch(frequency.to_sym, frequency.to_s.capitalize)
    mail(to: @user.email, subject: "Deine #{frequency_label} Manifold-Zusammenfassung")
  end

  def flag_notification(user, resource, message)
    user_assignment user
    @resource = resource.decorate
    @kind = resource.class.name.downcase
    @message = message
    subject = "Ein Inhalt wurde gemeldet"
    mail(to: @user.email, subject: subject)
  end

  def comment_notification(user, comment)
    user_assignment user
    @comment = comment.decorate
    mail(to: @user.email, subject: "Ein Kommentar wurde zu #{@comment.title} verfasst")
  end

  def annotation_notification(user, annotation)
    user_assignment user
    @annotation = annotation.decorate
    mail(to: @user.email, subject: "Eine Annotation wurde zu #{@annotation.text_title} erstellt")
  end

  def reply_notification(user, comment)
    user_assignment user
    @comment = comment.decorate
    subject = "Jemand hat auf deinen Kommentar zu #{@comment.title} geantwortet"
    mail(to: @user.email, subject: subject)
  end

  def reading_group_join_notification(user, reading_group_membership)
    user_assignment user
    @reading_group_membership = reading_group_membership.decorate
    subject = "Jemand ist deiner Lesegruppe \"#{@reading_group_membership.reading_group_name}\" beigetreten"
    mail(to: @user.email, subject: subject)
  end

  private

  def user_assignment(user)
    @user = user
    @unsubscribe_token = UnsubscribeToken.generate user
  end
end
