class AlterBacklogData < ActiveRecord::Migration
  def self.up
    add_column :backlog_chart_data, :total_hours, :float, :null => false
    add_column :backlog_chart_data, :time_spent, :float, :null => false
  end
  
  def self.down
    remove_column :backlog_chart_data, :time_spent
    remove_column :backlog_chart_data, :total_hours
  end
end
