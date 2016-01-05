module Draisine
  class SoapController < ApplicationController
    protect_from_forgery with: :null_session

    before_filter :validate_ip

    def update
      response = SoapHandler.new.update(params)
      render xml: response, status: :created
    end

    def delete
      response = SoapHandler.new.delete(params)
      render xml: response, status: :created
    end

    protected

    def validate_ip
      ip_checker = IpChecker.new(Draisine.allowed_ip_ranges)
      unless ip_checker.check(request.remote_ip)
        render nothing: true, status: :forbidden
      end
    end
  end
end
