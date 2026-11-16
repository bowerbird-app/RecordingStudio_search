# frozen_string_literal: true

return unless Rails.env.test?

# Users applies Devise confirmable at boot. Integration sign_in reloads the
# user, so an unconfirmed row is bounced to the email screen. Confirm here
# once, before the helper stores the id.
Rails.application.config.after_initialize do
  require "devise/test/integration_helpers"

  module TestSignInConfirmsUser
    def sign_in(resource, ...)
      if resource.respond_to?(:skip_confirmation!) && resource.respond_to?(:confirmed?) && !resource.confirmed?
        resource.skip_confirmation!
        resource.save!(validate: false) if resource.persisted? && resource.changed?
      end

      super
    end
  end

  helpers = Devise::Test::IntegrationHelpers
  helpers.prepend(TestSignInConfirmsUser) unless helpers.ancestors.include?(TestSignInConfirmsUser)
end
