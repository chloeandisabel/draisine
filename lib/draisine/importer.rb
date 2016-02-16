module Draisine
  class Importer
    attr_reader :model_class

    def initialize(model_class)
      @model_class = model_class
    end

    def import(start_id: nil, start_date: nil, batch_size: 500)
      find_each(batch_size: batch_size, start_id: start_id, start_date: start_date) do |sobj|
        attrs = sobj.attributes
        model_class.import_with_attrs(
          attrs.fetch("Id"),
          attrs.slice(*model_class.salesforce_synced_attributes))
      end
    end

    def import_new(batch_size: 500, start_date_window_size: 20.minutes)
      last_model = model_class.order("salesforce_id DESC").first
      start_id = last_model.try(:salesforce_id)
      start_date = last_model.try(:CreatedDate)
      start_date -= start_date_window_size if start_date

      import(start_id: start_id, batch_size: batch_size, start_date: start_date)
    end

    def import_fields(batch_size: 500, fields:)
      model_class.find_in_batches(batch_size: batch_size) do |batch|
        attempt do
          sobjs = client.fetch_multiple(model_class.salesforce_object_name, batch.map(&:salesforce_id), batch_size, fields)
          sobjs_map = sobjs.map {|sobj| [sobj.Id, sobj] }.to_h
          batch.each do |model|
            sobject = sobjs_map[model.salesforce_id]
            next unless sobject
            model.salesforce_assign_attributes(sobject.attributes.slice(*fields))
            model.salesforce_skipping_sync { model.save! }
          end
        end
      end
    end

    protected

    def find_each(batch_size:, start_id:, start_date: nil, &block)
      salesforce_model = client.materialize(salesforce_object_name)
      # if we have start_date set, only use id starting from the second query
      last_id = start_id unless start_date

      counter = 0
      loop do
        query = import_query(salesforce_model, salesforce_object_name, batch_size, last_id, start_date)
        collection = attempt { client.query(query) }
        break unless collection.count > 0

        model_class.transaction do
          collection.each do |sobj|
            yield sobj
          end
        end

        counter += collection.count
        last_id = collection.last.attributes.fetch("Id")
        logger.info "[#{model_class} import] Imported #{counter} records, last record id #{last_id}"
      end
      logger.info "[#{model_class} import] Finished, imported a total of #{counter} records"
    end

    def client
      Draisine.salesforce_client
    end

    def salesforce_object_name
      model_class.salesforce_object_name
    end

    def import_query(salesforce_model, salesforce_object_name, batch_size, start_id = nil, start_date = nil)
      conds = [
        start_id && "Id > '#{start_id}'",
        start_date && "CreatedDate >= #{start_date.iso8601}"
      ].compact
      where_clause = conds.presence && "WHERE #{conds.join(" AND ")}"

      <<-QUERY
      SELECT #{salesforce_model.field_list}
      FROM #{salesforce_object_name}
      #{where_clause}
      ORDER BY Id ASC
      LIMIT #{batch_size}
      QUERY
    end

    def attempt(times = 5)
      attempts ||= 0
      yield
    rescue => e
      attempts += 1
      logger.error "#{e.class}: #{e.message}"
      if attempts < times
        logger.error "Retrying... (attempt ##{attempts})"
        retry
      else
        logger.error "Too many attempts, failing..."
        raise
      end
    end

    def logger
      @logger ||= Rails.logger || Logger.new($stdout)
    end
  end
end
