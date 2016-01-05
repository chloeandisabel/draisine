class <%= @model_name %> < ActiveRecord::Base
  self.table_name = <%= @table_name.inspect %>
  <%- @serialized_columns.each do |col| -%>
  serialize :<%= col %>, JSON
  <%- end -%>

  salesforce_syncable <%= @columns.map(&:to_sym).inspect %>,
      non_audited_attributes: <%= @non_audited_columns.map(&:to_sym).inspect %>,
      array_attributes: <%= @array_columns.map(&:to_sym).inspect %>,
      salesforce_object_name: <%= @salesforce_object_name.inspect %>
end
