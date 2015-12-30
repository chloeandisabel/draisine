module Draisine
  # Wrapper around salesforce client implementation
  # Might have pluggable adapters in the future.
  class Syncer
    attr_reader :salesforce_object_name

    def initialize(salesforce_object_name, client = nil)
      @salesforce_object_name ||= salesforce_object_name
      @client = client
    end

    def get(id)
      raise ArgumentError unless id.present?
      response = client.http_get(build_sobject_url(id))
    end

    def create(attrs)
      response = client.http_post(build_sobject_url(nil), attrs.to_json)
      JSON.parse(response.body)
    end

    def update(id, attrs)
      raise ArgumentError unless id.present?
      return unless attrs.present?
      client.http_patch(build_sobject_url(id), attrs.to_json)
    end

    def delete(id)
      raise ArgumentError unless id.present?
      client.http_delete(build_sobject_url(id))
    end

    protected

    def client
      @client || Draisine.salesforce_client
    end

    def build_sobject_url(id)
      url = "/services/data/v#{client.version}/sobjects/#{salesforce_object_name}"
      url << "/#{id}" if url
      url
    end
  end
end
