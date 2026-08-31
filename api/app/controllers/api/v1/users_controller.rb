# frozen_string_literal: true

module API
  module V1
    # User controller
    class UsersController < ApplicationController
      PRELOADS = %w(roles).freeze

      resourceful! User, authorize_options: { except: [:create, :show, :whoami] } do
        User.preload(PRELOADS).filtered(**with_pagination!(user_filter_params))
      end

      def whoami
        return respond_with_forbidden("the authenticated user", "show") unless @current_user

        render_single_resource(@current_user)
      end

      def index
        @users = load_users
        render_multiple_resources(
          @users
        )
      end

      def show
        @user = load_and_authorize_user
        render_single_resource @user
      end

      def create
        create_params = public_signup? ? public_signup_params : user_params
        @user = ::Updaters::User.new(create_params).update(User.new)
        created_by_admin = create_params.dig("data", "meta", "created_by_admin") == true
        AccountMailer.welcome(@user, created_by_admin: created_by_admin).deliver if @user.valid?
        render_single_resource @user
      end

      def update
        @user = load_and_authorize_user
        ::Updaters::User.new(user_params).update(@user)
        render_single_resource @user
      end

      def destroy
        @user = load_and_authorize_user
        @user.destroy
      end

      private

      def public_signup?
        @current_user.blank?
      end

      def public_signup_params
        user_params.deep_dup.tap do |safe_params|
          attributes = safe_params.dig("data", "attributes")
          if attributes
            attributes["role"] = "reader"
            attributes.delete(:role)
            attributes.delete("kind")
            attributes.delete(:kind)
            attributes.delete("admin_verified")
            attributes.delete(:admin_verified)
            attributes.delete("verified_by_admin_at")
            attributes.delete(:verified_by_admin_at)
            attributes.delete("established")
            attributes.delete(:established)
            attributes.delete("trusted")
            attributes.delete(:trusted)
          end

          meta = safe_params.dig("data", "meta")
          if meta
            meta.delete("created_by_admin")
            meta.delete(:created_by_admin)
          end
        end
      end
    end
  end
end
