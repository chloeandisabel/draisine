module Draisine
  class ConflictResolver
    ALLOWED_RESOLUTIONS = %w[
      remote_push remote_pull local_delete merge
    ]

    attr_reader :model_class, :client, :salesforce_object_name,
                :local_id, :salesforce_id

    def initialize(model_class, client, local_id, salesforce_id)
      @model_class = model_class
      @client = client
      @salesforce_object_name = model_class.salesforce_object_name
      @local_id = local_id
      @salesforce_id = salesforce_id
    end

    def conflict?
      ConflictDetector.new(model, remote_model, model_class.salesforce_synced_attributes).conflict?
    end

    def resolve(resolution_type, options = {})
      resolution_type = resolution_type.to_s
      fail ArgumentError, "Unknown resolution type '#{resolution_type}'" unless allowed_resolution?(resolution_type)

      __send__(resolution_type, options)
    end

    def allowed_resolution?(resolution_type)
      ALLOWED_RESOLUTIONS.include?(resolution_type)
    end

    def remote_pull(_options = {})
      raise ArgumentError, "remote model is required for remote pull" unless remote_model

      model_class.salesforce_inbound_update(remote_model.attributes)
    end

    def remote_push(_options = {})
      raise ArgumentError, "local model is required for remote push" unless model

      if model.salesforce_id.present?
        model.salesforce_outbound_update(model.salesforce_attributes)
      else
        model.salesforce_outbound_create
      end
    end

    def remote_delete(_options = {})
      raise ArgumentError, "local model is required for remote delete" unless model

      model.salesforce_outbound_delete
    end

    def local_delete(_options = {})
      model_class.salesforce_inbound_delete(salesforce_id)
    end

    def merge(options)
      raise ArgumentError unless model && remote_model
      assert_required_options!(options, [:local_attributes, :remote_attributes])

      local_attrs_to_merge = options.fetch(:local_attributes)
      remote_attrs_to_merge = options.fetch(:remote_attributes)

      model.salesforce_outbound_update(
        model.salesforce_attributes.slice(*local_attrs_to_merge))
      model.salesforce_inbound_update(
        remote_model.attributes.slice(*remote_attrs_to_merge), false)
    end

    def model
      @model ||= if local_id
        model_class.find_by(id: local_id)
      else
        model_class.find_by(salesforce_id: salesforce_id)
      end
    end

    def remote_model
      return @remote_model unless @remote_model.nil?
      @remote_model = begin
        client.find(salesforce_object_name, salesforce_id)
      rescue Databasedotcom::SalesForceError
        false
      end
    end

    protected

    def assert_required_options!(options, keys)
      keys.each do |key|
        raise ArgumentError, "missing required option #{key}" unless options.key?(key)
      end
    end
  end
end
