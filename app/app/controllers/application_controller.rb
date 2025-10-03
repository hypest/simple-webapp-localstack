class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  # Health check endpoint for load balancer
  def health
    render json: { status: 'ok', timestamp: Time.current.iso8601 }
  end
end