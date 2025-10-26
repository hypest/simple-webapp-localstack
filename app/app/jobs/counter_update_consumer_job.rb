class CounterUpdateConsumerJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info("CounterUpdateConsumerJob: Starting to poll SQS messages")
    poll_sqs_messages
    Rails.logger.info("CounterUpdateConsumerJob: Finished polling SQS messages")
  end

  private

  def poll_sqs_messages
    Rails.logger.info("CounterUpdateConsumerJob: Polling for messages...")
    response = SQS_CLIENT.receive_message(
      queue_url: COUNTER_QUEUE_URL,
      max_number_of_messages: 10,
      wait_time_seconds: 20, # Long polling
      visibility_timeout: 30
    )

    messages = response.messages || []
    Rails.logger.info("CounterUpdateConsumerJob: Received #{messages.length} messages")
    
    if messages.empty?
      Rails.logger.info("CounterUpdateConsumerJob: No messages to process")
      return
    end

    messages.each do |message|
      Rails.logger.info("CounterUpdateConsumerJob: Processing message #{message.message_id}")
      process_message(message)
      delete_message(message.receipt_handle)
      Rails.logger.info("CounterUpdateConsumerJob: Processed and deleted message #{message.message_id}")
    end
  rescue => e
    Rails.logger.error("Error in CounterUpdateConsumerJob: #{e.message}")
    # Continue polling even if there's an error
  end

  def process_message(message)
    data = JSON.parse(message.body)
    counter_value = data['counter_value']
    instance_id = data['instance_id']

    Rails.logger.info("Received counter update: #{counter_value} from #{instance_id}")

    Counter.update_from_external(counter_value, instance_id)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse SQS message: #{e.message}")
  end

  def delete_message(receipt_handle)
    SQS_CLIENT.delete_message(
      queue_url: COUNTER_QUEUE_URL,
      receipt_handle: receipt_handle
    )
  rescue => e
    Rails.logger.error("Failed to delete SQS message: #{e.message}")
  end
end
