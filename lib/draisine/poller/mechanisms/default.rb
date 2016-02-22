module Draisine
  class Poller
    module Mechanisms
      class Default < Base
        def get_updated_ids(start_date, end_date)
          client.get_updated_ids(salesforce_object_name, start_date, end_date)
        end

        def get_deleted_ids(start_date, end_date)
          client.get_deleted_ids(salesforce_object_name, start_date, end_date)
        end
      end
    end
  end
end
