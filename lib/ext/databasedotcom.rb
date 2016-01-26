module Databasedotcom
  class Client
    # Fetches a collection of sobjects with given ids
    # Useful in conjunction with get_updated / get_deleted calls
    def fetch_multiple(classname, ids, batch_size = 100)
      return [] unless ids.present?
      klass = find_or_materialize(classname)

      ids.in_groups_of(batch_size).flat_map do |ids|
        query <<-EOQ
        SELECT #{klass.field_list}
        FROM #{klass.sobject_name}
        WHERE id IN (#{ids.map {|id| "'%s'" % id}.join(',')})
        EOQ
      end
    end

    # Returns a list of updated sobject ids for provided date range
    # reference: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_getupdated.htm?search_text=getUpdated
    def get_updated(classname, start_date, end_date = Time.now)
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

    # Returns a list of updated sobject ids for provided date range
    # reference: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_getdeleted.htm?search_text=getUpdated
    def get_deleted(classname, start_date, end_date = Time.now)
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
end
