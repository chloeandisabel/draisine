class <%= @migration_title %> < ActiveRecord::Migration
  def up
    change_table :<%= @table_name %>, bulk: true do |t|
      <%- @new_ar_col_defs.each do |col_def| -%>
      t.column :<%= col_def.column_name %>, :<%= col_def.column_type %>, <%= col_def.options.inspect %>
      <%- end -%>
      <%- @changed_ar_col_defs.each do |col_def| -%>
      t.change :<%= col_def.column_name %>, :<%= col_def.column_type %>, <%= col_def.options.inspect %>
      <%- end -%>
    end
  end

  def down
    change_table :<%= @table_name %>, bulk: true do |t|
      <%- @new_ar_col_defs.each do |col_def| -%>
      t.remove :<%= col_def.column_name %>
      <%- end -%>
      <%- @changed_ar_col_defs.each do |col_def| -%>
      <%- ex_col = @existing_columns[col_def.column_name] -%>
      t.change :<%= ex_col.column_name %>, :<%= ex_col.column_type %>, <%= ex_col.options.inspect %>
      <%- end -%>
    end
  end
end
