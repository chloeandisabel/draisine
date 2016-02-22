module Databasedotcom
  class Client
    # Fetches a collection of sobjects with given ids
    # Useful in conjunction with get_updated / get_deleted calls
    def fetch_multiple(classname, ids, batch_size = 100, field_list = nil)
      return [] unless ids.present?
      klass = find_or_materialize(classname)
      field_list ||= klass.field_list.split(",")
      field_list = field_list | ["Id"]
      field_list = field_list.join(",")
      ids.in_groups_of(batch_size).flat_map do |ids|
        query <<-EOQ
        SELECT #{field_list}
        FROM #{klass.sobject_name}
        WHERE id IN (#{ids.map {|id| "'%s'" % id}.join(',')})
        EOQ
      end
    end

    # Returns a list of updated sobject ids for provided date range
    # reference: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_getupdated.htm?search_text=getUpdated
    def get_updated(classname, start_date, end_date = Time.current)
      result = http_get("/services/data/v#{self.version}/sobjects/#{classname}/updated",
                        start: prepare_date_arg(start_date),
                        end: prepare_date_arg(end_date))
      JSON.parse(result.body)
    rescue Databasedotcom::SalesForceError => e
      if e.message.include?("is not replicable")
        {}
      else
        raise
      end
    end

    def get_updated_ids(classname, start_date, end_date = Time.current)
      get_updated(classname, start_date, end_date).fetch("ids", [])
    end

    # Returns a list of updated sobject ids for provided date range
    # reference: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_getdeleted.htm?search_text=getUpdated
    def get_deleted(classname, start_date, end_date = Time.current)
      result = http_get("/services/data/v#{self.version}/sobjects/#{classname}/deleted",
                        start: prepare_date_arg(start_date),
                        end: prepare_date_arg(end_date))
      JSON.parse(result.body)
    rescue Databasedotcom::SalesForceError => e
      if e.message.include?("is not replicable")
        {}
      else
        raise
      end
    end

    def get_deleted_ids(classname, start_date, end_date = Time.current)
      get_deleted(classname, start_date, end_date).fetch("deletedRecords", []).map {|r| r["id"] }
    end

    def count(classname)
      query("SELECT COUNT() FROM #{classname}").total_size
    end

    protected

    def prepare_date_arg(date)
      return date.to_time.iso8601 if date.respond_to?(:to_time)
      date
    end

    def find_or_materialize(class_or_classname)
      if class_or_classname.is_a?(Class)
        clazz = class_or_classname
      else
        match = class_or_classname.match(/(?:(.+)::)?(\w+)$/)
        preceding_namespace = match[1]
        classname = match[2]
        raise ArgumentError if preceding_namespace && preceding_namespace != module_namespace.name
        clazz = module_namespace.const_get(classname.to_sym, false) rescue nil # fix inherited namespace
        clazz ||= self.materialize(classname)
      end
      clazz
    end
  end

  module Sobject
    module NumericFieldsExtensions
      def register_field(name, field)
        super
        %w[scale precision length byteLength].each do |attr|
          self.type_map[name][attr.underscore.to_sym] = field[attr] if field[attr]
        end
      end
    end

    class <<Sobject
      prepend NumericFieldsExtensions
    end
  end
end
