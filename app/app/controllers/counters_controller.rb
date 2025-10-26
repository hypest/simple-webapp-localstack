class CountersController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:increment]

  def index
    @counter_value = Counter.current_value
  end

  def increment
    new_value = Counter.increment!

    # Publish to SQS
    publish_counter_update(new_value)

    respond_to do |format|
      format.html { redirect_to counters_path }
      format.turbo_stream
    end
  end

  private

  def publish_counter_update(value)
    message_body = {
      counter_value: value,
      instance_id: Counter.singleton.instance_id,
      timestamp: Time.current.iso8601
    }.to_json

    SQS_CLIENT.send_message(
      queue_url: COUNTER_QUEUE_URL,
      message_body: message_body
    )
  rescue => e
    Rails.logger.error("Failed to publish counter update to SQS: #{e.message}")
    # Don't fail the request if SQS publishing fails
  end
end
