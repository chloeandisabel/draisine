module Draisine
  class SoapController < ApplicationController
    protect_from_forgery with: :null_session

    def update
      response = SoapHandler.new.update(params)
      render xml: response, status: :created
    end

    def delete
      response = SoapHandler.new.delete(params)
      render xml: response, status: :created
    end
  end
end
