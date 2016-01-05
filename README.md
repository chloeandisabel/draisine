# Draisine

![Cho-choo](https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/GAZ-13_Chaika_draisine.jpg/600px-GAZ-13_Chaika_draisine.jpg)

A bi-directional syncing solution for Salesforce and ActiveRecord.

Gem overall design is heavily inspired by InfoTech's [salesforce_ar_sync gem](https://github.com/InfoTech/salesforce_ar_sync), but with focus on clearer and more modular code.

## Dependencies

* Rails 4.2+ (for ActiveJob)
* databasedotcom (for salesforce connections)


## Installation and configuration

After you've got the gem installed, you will need to setup the salesforce client. For example:

```
sf_client = Databasedotcom::Client.new("config/databasedotcom.yml")
sf_client.authenticate :username => <username>, :password => <password>
Draisine.salesforce_client = sf_client
```

You will also need to have your organization id set up:

```
Draisine.organization_id = '123456789012345678'
```

Use this [tool](https://cloudjedi.wordpress.com/no-fuss-salesforce-id-converter/) to convert your 15-char org id into 18-char.

## Usage

Draisine adds a `salesforce_syncable` macro to ActiveRecord models, used like this:

```
class Lead < Salesforce::Model
  salesforce_syncable synced_attributes: [:FirstName, :LastName, ...],
    mapping: { 'FirstName' => 'first_name', 'LastName' => 'last_name' },
    operations: [:outbound_create, :outbound_update, :outbound_delete, :inbound_update, :inbound_delete],
    salesforce_object_name: 'Lead',
    sync: true
end
```

Your model class must have `salesforce_id` string column for everything to work.

### Available options

#### salesforce_object_name (String)

Self-explanatory. Defaults to the class name.

#### synced_attributes (Array[Symbol|String], required)

List of all Salesforce attributes that are required to be synced. If your ActiveRecord attributes should have different names, you can remap them later.

#### mapping (Hash[String => String])

#### sync (Boolean, default: true)

When set to true, all jobs are launched inline (via `#perform_now`), otherwise, they are set to perform as soon as workers get to them (`#perform_later`).

#### operations (Array[Symbol])

List of operations that must be synced with Salesforce.

Available operations: `[:outbound_create, :outbound_update, :outbound_delete, :inbound_update, :inbound_delete]`

#### non_audited_attributes (Array[Symbol|String])

## Setting up outbound messages

## Handling inbound deletes

## Error handling

You can setup handling most transient errors using `Draisine.job_error_handler = proc {|exception, job, arguments| }` setter. It will be called every time a job, such as `InboundUpdateJob` fails with any error.

## Roadmap


* ~~ActiveRecord plugin and hooks~~
* ~~ActiveRecord -> Salesforce synchronization (outbound creates, updates, deletes)~~
* ~~ActiveJob delayed jobs~~
* ~~Salesforce -> ActiveRecord inbound updates~~
* ~~Salesforce -> ActiveRecord inbound deletes~~
* ~~Error handling inside delayed jobs~~
* ~Auditing~
* ~Migration generator~
* ~Conflict resolution~
* Use restforce instead of / alongside of databasedotcom


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/markiz/draisine.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

