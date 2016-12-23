module Draisine
  class SoapController < ApplicationController
    protect_from_forgery with: :null_session

    before_filter :validate_ip

    def update
      message = request.body.read
      if Draisine.sync_soap_operations?
        Draisine::SoapUpdateJob.perform_now(message)
      else
        Draisine::SoapUpdateJob.perform_later(message)
      end

      render xml: xml_response, status: :created
    end

    def delete
      message = request.body.read
      if Draisine.sync_soap_operations?
        Draisine::SoapDeleteJob.perform_now(message)
      else
        Draisine::SoapDeleteJob.perform_later(message)
      end

      render xml: xml_response, status: :created
    end

    protected

    def validate_ip
      ip_checker = IpChecker.new(Draisine.allowed_ip_ranges)
      unless ip_checker.check(request.remote_ip)
        render nothing: true, status: :forbidden
      end
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
  end
end
