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

In the left sidebar of salesforce interface, choose Create -> Workflow & Approvals -> Workflow Rules. Then click "New Rule". The rest is more or less self-explanatory. You would want to have all the necessary fields attached to your outbound message.

Assuming you mount draisine engine to `/salesforce`, endpoint url would be `/salesforce/sf_soap/lead` (for Lead object). Make sure you use full proper URL since salesforce will not follow redirects.

You can check out status for the latest sent messages in the Monitoring -> Outbound Messages section.

## Handling special object types, e.g. `LeadHistory`

Some object types in salesforce are not directly user-editable and can't be set up to send outbound messages. One example of such object is LeadHistory. That means you'll have to poll them yourselves. Easiest way to do so is sort by `Id` both on your model (also known as `salesforce_id`) and at salesforce and get only the records with Id > max(salesforce_id).

## Handling inbound deletes

Salesforce only sends outbound messages for record creates and updates, to sync deletes you'll have to go extra mile. You'll need to create a custom object, called `Deleted_Object` that has two fields: `Object_Id (text (18))` and `Object_Type (text (128))` and a trigger for every observed model that creates an instance of such object after every delete. Then you'll need to setup outbound messaging, like for a normal model, but use `/sf_soap/delete` instead of `/sf_soap/<modelname>` for endpoint.

See a [trigger example](salesforce/sample_delete_trigger.apex) and a [corresponding test class](salesforce/sample_test_class_for_delete_trigger.apex).


### How to create trigger on your production instance

You might notice that unlike your sandbox instance, your production instance doesn't have "new trigger" button. Congratulations and welcome to Salesforce! You can't create new triggers on production instances directly, you'll have to use something called inbound/outbound change sets. In a nutshell, it's a protocol for generic object exchange between salesforce instances. Long story short, you'll need to export your apex trigger with its test class from sandbox to production instance.

To do so, go Deploy -> Outbound Change Set -> New -> etc etc etc.

If you export Deleted Object this way, don't forget to add custom fields to your change set. Also you must add test coverage for your trigger to the changeset or it won't apply. Good luck.


## Error handling

You can setup handling most transient errors using `Draisine.job_error_handler = proc {|exception, job, arguments| }` setter. It will be called every time a job, such as `InboundUpdateJob` fails with any error.

## Roadmap


* ~~ActiveRecord plugin and hooks~~
* ~~ActiveRecord -> Salesforce synchronization (outbound creates, updates, deletes)~~
* ~~ActiveJob delayed jobs~~
* ~~Salesforce -> ActiveRecord inbound updates~~
* ~~Salesforce -> ActiveRecord inbound deletes~~
* ~~Error handling inside delayed jobs~~
* ~~Auditing~~
* ~~Migration generator~~
* ~~Conflict resolution~~
* Use restforce instead of / alongside databasedotcom


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/chloeandisabel/draisine.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

