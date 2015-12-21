module Draisine
  def self.salesforce_client=(client)
    @salesforce_client = client
  end

  def self.salesforce_client
    unless @salesforce_client
      fail <<-EOM
DatabaseDotcom client was not properly set up. You can set it up as follows:
sf_client = Databasedotcom::Client.new("config/databasedotcom.yml")
sf_client.authenticate :username => <username>, :password => <password>
Draisine.salesforce_client = sf_client
EOM
    end
    @salesforce_client
  end

  def self.organization_id
    fail <<-EOM
Draisine.organization_id was not properly set up.
You can use Draisine.organization_id= method to set it.
See https://cloudjedi.wordpress.com/no-fuss-salesforce-id-converter/ if
you need to convert your 15-char id into 18-char.
EOM
    @organization_id
  end

  def self.organization_id=(id)
    unless id.kind_of?(String) && id.length == 18
      fail ArgumentError, "You should set organization id to an 18 character string"
    end
    @organization_id = id
  end

  def self.job_error_handler
    @job_error_handler ||= proc { }
  end

  def self.job_error_handler=(handler)
    @job_error_handler = handler
  end
end
