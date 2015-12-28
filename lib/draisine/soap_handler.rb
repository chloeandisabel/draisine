module Draisine
  class SoapHandler
    def initialize
    end

    def update(message)
      assert_valid_message!(message)
      extract_sobjects(message).each do |sobject|
        type = sobject.fetch('xsi:type').sub('sf:', '')
        klass = Draisine.registry.find(type)
        klass.salesforce_on_inbound_update(sobject)
      end
      xml_response
    end

    def delete(message)
      assert_valid_message!(message)
      extract_sobjects(message).each do |sobject|
        type = sobject.fetch('Object_Type__c')
        id = sobject.fetch('Object_Id__c')
        klass = Draisine.registry.find(type)
        klass.salesforce_on_inbound_delete(id)
      end
      xml_response
    end

    def xml_response
      <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<soapenv:Body>
<notificationsResponse><Ack>true</Ack></notificationsResponse>
</soapenv:Body>
</soapenv:Envelope>
EOF
    end

    protected

    def extract_sobjects(message)
      Array.wrap(message['Envelope']['Body']['notifications']['Notification']).map do |sobject|
        sobject.fetch('sObject')
      end
    end

    def assert_valid_organization_id!(message)
      unless diggable_to?(message, ['Envelope', 'Body', 'notifications', 'OrganizationId']) &&
             message['Envelope']['Body']['notifications']['OrganizationId'] == Draisine.organization_id

        fail ArgumentError, "invalid organization id in the inbound message from salesforce"
      end
    end

    def assert_valid_message!(message)
      assert_valid_organization_id!(message)
      unless diggable_to?(message, ['Envelope', 'Body', 'notifications', 'Notification'])
        fail ArgumentError, "malformed xml inbound message from salesforce"
      end
    end

    def diggable_to?(hash, path)
      path.each do |key|
        return false unless hash.respond_to?(:key?) && hash.key?(key)
        hash = hash[key]
      end
      true
    end
  end
end
