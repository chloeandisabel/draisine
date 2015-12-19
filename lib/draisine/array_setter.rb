require "active_support/concern"

module Draisine
  module ArraySetter
    extend ActiveSupport::Concern

    module ClassMethods
      def salesforce_array_setter(attr)
        mod = Module.new do
          define_method "#{attr}=" do |value|
            value = [] if value.nil?
            value = value.split(';') if value.kind_of?(String)
            super(value)
          end
        end
        prepend mod
        attr
      end
    end
  end
end
