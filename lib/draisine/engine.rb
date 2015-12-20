require 'rails'
require 'action_dispatch/xml_params_parser'

module Draisine
  class Engine < ::Rails::Engine
    initializer 'draisine.insert_xml_parser_middleware' do |app|
      app.config.middleware.insert_after ActionDispatch::ParamsParser, ActionDispatch::XmlParamsParser
    end
  end
end
