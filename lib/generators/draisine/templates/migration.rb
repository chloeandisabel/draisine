class <%= @migration_title %> < ActiveRecord::Migration
  def up
    create_table :<%= @table_name %> do |t|
      <%- @ar_col_defs.each do |col_def| -%>
      t.column :<%= col_def.column_name %>, :<%= col_def.column_type %>, <%= col_def.options.inspect %>
      <%- end -%>

      # These are draisine-specific columns
      t.column :salesforce_id, :string, :limit => 18
      t.column :salesforce_updated_at, :datetime
      t.index :salesforce_id, :unique => true
    end
  end

  def down
    drop_table :<%= @table_name %>
  end
end
