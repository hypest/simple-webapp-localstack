class Counter < ApplicationRecord
  validates :value, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :instance_id, presence: true

  # Get the singleton counter record, create if doesn't exist
  def self.singleton
    first_or_create(value: 0, instance_id: instance_identifier)
  end

  # Increment the counter and return the new value
  def self.increment!
    counter = singleton
    counter.with_lock do
      counter.update!(value: counter.value + 1, instance_id: instance_identifier)
    end
    counter.value
  end

  # Get current counter value
  def self.current_value
    singleton.value
  end

  # Update counter from external source (SQS message)
  def self.update_from_external(new_value, external_instance_id)
    return if external_instance_id == instance_identifier # Don't update from self

    counter = singleton
    counter.with_lock do
      counter.update!(value: new_value, instance_id: external_instance_id)
    end
  end

  private

  def self.instance_identifier
    ENV.fetch('RAILS_APP_INSTANCE_ID', "instance-#{Process.pid}")
  end
end
