# frozen_string_literal: true

# The landing page's newsletter dialog posts here; the beehiiv call stays
# server-side (app/lib/beehiiv.rb) so no key or third-party script ever
# reaches the browser.
class SubscriptionsController < ApplicationController
  GENERIC_FAILURE = "We could not subscribe you. Please try again."

  def create
    # The honeypot: a hidden "website" input no person ever fills. Report
    # success so bots learn nothing.
    return render json: { ok: true } if params[:website].present?

    email = params[:email].to_s.strip
    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      return render json: { ok: false, error: "Enter a valid email address." },
                    status: :unprocessable_entity
    end

    unless Beehiiv.configured?
      return render json: { ok: false, error: "Subscriptions are not set up yet. Please try again later." },
                    status: :service_unavailable
    end

    Beehiiv.subscribe(email: email, referring_site: request.origin)
    render json: { ok: true }
  rescue Beehiiv::Error, Timeout::Error, SocketError, SystemCallError => error
    Rails.logger.warn("beehiiv subscribe failed: #{error.class}: #{error.message}")
    render json: { ok: false, error: GENERIC_FAILURE }, status: :bad_gateway
  end
end
