module Draisine
  class CachingClient
    class Cache
      attr_reader :cache

      def initialize
        @cache = {}
      end

      def [](key)
        cache[key]
      end

      def fetch(key, &block)
        cache.fetch(key) { cache[key] = yield }
      end

      def []=(key, value)
        cache[key] = value
      end

      def add(record)
        self[record.attributes.fetch('Id')] = record
      end

      def add_multiple(records)
        records.each {|record| add(record) }
      end

      def has_ids?(ids)
        (ids - cache.keys).empty?
      end

      def fetch_multiple(ids, &block)
        if has_ids?(ids)
          cache.values_at(*ids)
        else
          yield.tap do |records|
            add_multiple(records)
          end
        end
      end
    end

    attr_reader :cache_map, :client

    def initialize(client = Draisine.salesforce_client)
      @cache_map = Hash.new {|h,k| h[k] = Cache.new }
      @client = client
    end

    def find(salesforce_object_name, id)
      cache_map[salesforce_object_name].fetch(id) do
        client.find(salesforce_object_name, id)
      end
    end

    def fetch_multiple(salesforce_object_name, ids)
      cache_map[salesforce_object_name].fetch_multiple(ids) do
        client.fetch_multiple(salesforce_object_name, ids)
      end
    end
    alias_method :prefetch, :fetch_multiple

    def method_missing(method, *args, &block)
      if client.respond_to?(method)
        client.__send__(method, *args, &block)
      else
        super
      end
    end
  end
end
