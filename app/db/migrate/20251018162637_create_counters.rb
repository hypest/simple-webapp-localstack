class CreateCounters < ActiveRecord::Migration[8.0]
  def change
    create_table :counters do |t|
      t.integer :value
      t.string :instance_id

      t.timestamps
    end
  end
end
