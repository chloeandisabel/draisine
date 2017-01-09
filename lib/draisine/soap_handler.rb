require 'active_support/core_ext/hash/conversions'
require 'active_support/core_ext/hash/indifferent_access'

module Draisine
  class SoapHandler
    InvalidOrganizationError = Class.new(StandardError)

    def initialize
    end

    def update(message_xml)
      message = parse(message_xml)

      assert_valid_message!(message)
      extract_sobjects(message).each do |sobject|
        type = sobject.fetch('xsi:type').sub('sf:', '')
        klass = Draisine.registry.find(type)
        klass.salesforce_on_inbound_update(sobject)
      end
    rescue InvalidOrganizationError => e
      Draisine.invalid_organization_handler.call(message)
    end

    def delete(message_xml)
      message = parse(message_xml)

      assert_valid_message!(message)
      extract_sobjects(message).each do |sobject|
        type = sobject.fetch('Object_Type__c')
        id = sobject.fetch('Object_Id__c')
        klass = Draisine.registry.find(type)
        klass.salesforce_on_inbound_delete(id)
      end
    rescue InvalidOrganizationError => e
      Draisine.invalid_organization_handler.call(message)
    end

    protected

    def parse(message_xml)
      case message_xml
      when Hash
        message_xml
      when String
        Hash.from_xml(message_xml)
      else
        raise ArgumentError
      end
    end

    def extract_sobjects(message)
      Array.wrap(message['Envelope']['Body']['notifications']['Notification']).map do |sobject|
        sobject.fetch('sObject')
      end
    end

    def assert_valid_organization_id!(message)
      unless diggable_to?(message, ['Envelope', 'Body', 'notifications', 'OrganizationId']) &&
             message['Envelope']['Body']['notifications']['OrganizationId'] == Draisine.organization_id
        fail InvalidOrganizationError, "a message from invalid organization id received, source xml: #{message.inspect}"
      end
    end

    def assert_valid_message!(message)
      unless diggable_to?(message, ['Envelope', 'Body', 'notifications', 'Notification'])
        fail ArgumentError, "malformed xml inbound message from salesforce, source xml: #{message.inspect}"
      end
      assert_valid_organization_id!(message)
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
