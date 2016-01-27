class <%= @migration_title %> < ActiveRecord::Migration
  def up
    change_table :<%= @table_name %> do |t|
      <%- @ar_col_defs.each do |col_def| -%>
      t.column :<%= col_def.column_name %>, :<%= col_def.column_type %>, <%= col_def.options.inspect %>
      <%- end -%>
    end
  end

  def down
    change_table :<%= @table_name %> do |t|
      <%- @ar_col_defs.each do |col_def| -%>
      t.remove_column :<%= col_def.column_name %>
      <%- end -%>
    end
  end
end
