require "active_support/core_ext"
require "active_support/concern"

module Draisine
  ALL_OPS = [:outbound_create, :outbound_update, :outbound_delete,
             :inbound_update, :inbound_delete]

  module ActiveRecordMacro
    def salesforce_syncable(options)
      include Draisine::ActiveRecordPlugin

      self.salesforce_object_name = options.fetch(:salesforce_object_name, name)
      self.salesforce_synced_attributes = options.fetch(:synced_attributes, []).map(&:to_s)
      self.salesforce_mapping = options.fetch(:mapping, {}).map {|k,v| [k.to_s, v.to_s] }.to_h
      self.salesforce_ops = Set.new(options.fetch(:operations, ALL_OPS))

      options.fetch(:array_attributes, []).each do |attr|
        salesforce_array_setter(attr)
      end
    end
  end

  module ActiveRecordPlugin
    extend ActiveSupport::Concern
    include Draisine::ArraySetter
    include Draisine::AttributesMapping

    module ClassMethods
      attr_accessor :salesforce_object_name
      attr_accessor :salesforce_synced_attributes
      attr_accessor :salesforce_ops

      ALL_OPS.each do |op|
        define_method("salesforce_#{op}?") do
          salesforce_ops.include?(op)
        end
      end

      def salesforce_inbound_create_or_update(attributes)
        if salesforce_inbound_update?
          attributes = attributes.with_indifferent_access
          id = attributes.fetch('Id')
          (find_by(salesforce_id: id) || new).tap do |m|
            m.salesforce_id = id
            m.salesforce_inbound_update(attributes)
          end
        end
      end

      def salesforce_inbound_delete(id)
        if salesforce_inbound_delete?
        end
      end

      def salesforce_syncer
        @salesforce_syncer ||= Syncer.new(salesforce_object_name)
      end
    end

    attr_accessor :salesforce_skip_sync

    included do
      before_create :salesforce_on_create
      before_update :salesforce_on_update
      before_destroy :salesforce_on_delete
    end

    [:create, :update, :delete].each do |op|
      define_method "salesforce_on_#{op}" do
        if !salesforce_skip_sync && self.class.__send__("salesforce_outbound_#{op}?")
          __send__("salesforce_outbound_#{op}")
        end
      end
    end

    def salesforce_inbound_update(attributes)
      self.salesforce_skip_sync = true
      attributes_with_blanks = self.class.salesforce_synced_attributes
        .map {|attr| [attr, attributes[attr]] }
        .to_h
      salesforce_assign_attributes(attributes_with_blanks)
      save!
    end

    def salesforce_outbound_create
      response = salesforce_syncer.create(salesforce_attributes.compact)
      self.salesforce_id = response['id']
    end

    def salesforce_outbound_update
      updated_attributes = salesforce_attributes.slice(*changed)
      salesforce_syncer.update(salesforce_id, updated_attributes)
    end

    def salesforce_outbound_delete
      salesforce_syncer.delete(salesforce_id)
    end

    protected

    def salesforce_attributes
      salesforce_reverse_mapped_attributes(attributes)
        .with_indifferent_access
        .slice(*self.class.salesforce_synced_attributes)
    end

    def salesforce_syncer
      self.class.salesforce_syncer
    end
  end

  def self.register_ar_macro
    ActiveRecord::Base.extend(Draisine::ActiveRecordMacro)
  end
end

if defined?(ActiveRecord::Base)
  Draisine.register_ar_macro
end
