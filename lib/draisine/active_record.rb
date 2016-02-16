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
      self.salesforce_sync_mode = options.fetch(:sync, true)
      non_audited_attrs = options.fetch(:non_audited_attributes, []).map(&:to_s)
      self.salesforce_audited_attributes = salesforce_synced_attributes - non_audited_attrs

      options.fetch(:array_attributes, []).each do |attr|
        salesforce_array_setter(attr)
      end

      Draisine.registry.register(self, salesforce_object_name)
    end
  end

  module ActiveRecordPlugin
    extend ActiveSupport::Concern
    include Draisine::Concerns::ArraySetter
    include Draisine::Concerns::AttributesMapping

    module ClassMethods
      attr_accessor :salesforce_object_name
      attr_accessor :salesforce_synced_attributes
      attr_accessor :salesforce_audited_attributes
      attr_accessor :salesforce_ops
      attr_accessor :salesforce_sync_mode

      ALL_OPS.each do |op|
        define_method("salesforce_#{op}?") do
          salesforce_ops.include?(op)
        end
      end

      def salesforce_enqueue_or_run(job_class, *args, &block)
        if salesforce_sync_mode
          job_class.perform_now(*args, &block)
        else
          job_class.perform_later(*args, &block)
        end
      end

      def salesforce_on_inbound_update(attributes)
        salesforce_enqueue_or_run(InboundUpdateJob, self.name, attributes)
      end

      def salesforce_inbound_update(attributes, add_blanks = true)
        if salesforce_inbound_update?
          attributes = attributes.with_indifferent_access
          id = attributes.fetch('Id')
          (find_by(salesforce_id: id) || new).tap do |m|
            m.salesforce_id = id
            m.salesforce_inbound_update(attributes, add_blanks)
          end
        end
      end

      def salesforce_on_inbound_delete(salesforce_id)
        salesforce_enqueue_or_run(InboundDeleteJob, self.name, salesforce_id)
      end

      def salesforce_inbound_delete(salesforce_id)
        if salesforce_inbound_delete?
          record = find_by(salesforce_id: salesforce_id)
          if record
            record.salesforce_skip_sync = true
            record.destroy
            salesforce_callback(:inbound_delete, salesforce_id)
          end
        end
      end

      def salesforce_syncer
        @salesforce_syncer || Syncer.new(salesforce_object_name)
      end

      def salesforce_callback(type, salesforce_id, options = {})
        Draisine.sync_callback.call(type, salesforce_id, options)
      end

      # Doesn't update record if found
      def import_with_attrs(sf_id, attrs)
        find_or_initialize_by(salesforce_id: sf_id) do |model|
          model.salesforce_update_without_sync(attrs)
        end
      end

      # Does update record if found
      def import_or_update_with_attrs(sf_id, attrs, check_modstamp = false)
        find_or_initialize_by(salesforce_id: sf_id).tap do |model|
          model.salesforce_update_without_sync(attrs, check_modstamp)
        end
      end
    end

    attr_accessor :salesforce_skip_sync

    included do
      after_create :salesforce_on_create
      after_update :salesforce_on_update
      after_destroy :salesforce_on_delete
    end

    def salesforce_inbound_update(attributes, add_blanks = true)
      return unless salesforce_fresh_update?(attributes)
      self.salesforce_skip_sync = true
      if add_blanks
        attributes = self.class.salesforce_synced_attributes
          .map {|attr| [attr, attributes[attr]] }
          .to_h
      end
      salesforce_assign_attributes(attributes)
      salesforce_callback(persisted? ? :inbound_update : :inbound_create, attributes: attributes)
      save!
    end

    def salesforce_on_create
      if !salesforce_skip_sync && self.class.salesforce_outbound_create?
        self.class.salesforce_enqueue_or_run(OutboundCreateJob, self)
      end
    end

    def salesforce_outbound_create
      attrs = salesforce_attributes.compact
      response = salesforce_syncer.create(attrs)
      self.salesforce_id = response.fetch('id')
      salesforce_skipping_sync { save! } if persisted?
      salesforce_callback(:outbound_create, attributes: attrs)
    end

    def salesforce_on_update
      if !salesforce_skip_sync && self.class.salesforce_outbound_update?
        self.class.salesforce_enqueue_or_run(
          OutboundUpdateJob,
          self,
          salesforce_attributes.slice(*changed)
        )
      end
    end

    def salesforce_outbound_update(updated_attributes)
      self.class.transaction do
        salesforce_syncer.update(salesforce_id, updated_attributes)
        timestamp = salesforce_syncer.get_system_modstamp(salesforce_id)
        update_column(:salesforce_updated_at, timestamp)
        salesforce_callback(:outbound_update, attributes: updated_attributes)
      end
    end

    def salesforce_on_delete
      if !salesforce_skip_sync && self.class.salesforce_outbound_delete?
        self.class.salesforce_enqueue_or_run(OutboundDeleteJob, self)
      end
    end

    def salesforce_outbound_delete
      salesforce_syncer.delete(salesforce_id)
      salesforce_callback(:outbound_delete)
    end

    def salesforce_skipping_sync(&block)
      old_sync = self.salesforce_skip_sync
      self.salesforce_skip_sync = true
      instance_eval(&block)
    ensure
      self.salesforce_skip_sync = old_sync
    end

    def salesforce_attributes
      salesforce_reverse_mapped_attributes(attributes)
        .with_indifferent_access
        .slice(*self.class.salesforce_synced_attributes)
    end

    def salesforce_callback(type, options = {})
      self.class.salesforce_callback(type, salesforce_id, {
        local_record_type: self.class.name,
        local_record_id: id
      }.merge(options))
    end

    def salesforce_update_without_sync(attrs, check_modstamp = false)
      salesforce_skipping_sync do
        modstamp = attrs["SystemModstamp"]
        if !check_modstamp || !modstamp || !self.SystemModstamp || self.SystemModstamp < modstamp
          salesforce_assign_attributes(attrs)
          save!
        end
      end
    end

    protected

    def salesforce_fresh_update?(attributes)
      !salesforce_updated_at || !attributes['SystemModstamp'] ||
        Draisine.parse_time(attributes['SystemModstamp']) > salesforce_updated_at
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
