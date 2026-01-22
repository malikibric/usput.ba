# frozen_string_literal: true

# Configure session to persist for 2 weeks
Rails.application.config.session_store :cookie_store,
  key: "_usput_session",
  expire_after: 2.weeks,
  secure: Rails.env.production?,
  same_site: :lax
