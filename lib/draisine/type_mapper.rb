module Draisine
  class TypeMapper
    Type = Struct.new(:ar_type, :ar_options, :serialized, :array)

    ActiveRecordColumnDef = Struct.new(:column_name, :column_type, :options) do
      def self.from_ar_column(ar_col)
        new(ar_col.name, ar_col.type, { limit: ar_col.limit }.compact)
      end
    end

    MAX_ALLOWED_STRING_TYPE_LENGTH = 40

    def self.type(ar_type, ar_options: {}, serialized: false, array: false)
      Type.new(ar_type, ar_options, serialized, array)
    end

    def self.determine_type_for_float(name, sf_schema)
      if (precision = sf_schema[:precision]) && (scale = sf_schema[:scale]) && scale == 0
        type(:integer, ar_options: { limit: 8 })
      else
        type(:float, ar_options: { limit: 53 })
      end
    end

    def self.determine_type_for_string(name, sf_schema)
      if (length = sf_schema[:length]) && length > 0 && length <= MAX_ALLOWED_STRING_TYPE_LENGTH
        type(:string, ar_options: { limit: length })
      else
        type(:text)
      end
    end

    # Apparently, mysql has a hard limit of 64k per row.
    # That's why we're using text types where we could also use strings.
    TYPES_MAP = {
      "boolean" => type(:boolean),
      "string" => method(:determine_type_for_string),
      "reference" => type(:string, ar_options: { limit: 20 }),
      "picklist" => type(:binary, serialized: true),
      "textarea" => method(:determine_type_for_string),
      "phone" => method(:determine_type_for_string),
      "email" => method(:determine_type_for_string),
      "url" => method(:determine_type_for_string),
      "int" => type(:integer),
      "date" => type(:date),
      "time" => type(:time),
      "multipicklist" => type(:binary, serialized: true, array: true),
      "double" => method(:determine_type_for_float),
      "datetime" => type(:datetime),
      "anyType" => type(:binary, serialized: true),
      "combobox" => type(:text),
      "currency" => type(:decimal, ar_options: { precision: 18, scale: 6 }),
      "percent" => type(:decimal, ar_options: { precision: 18, scale: 6 })
      # Leave this one for now
      # "encrypted_string" => :string,
    }

    EXCLUDED_COLUMNS = ["Id"]

    attr_reader :sf_type_map, :type_map
    def initialize(sf_type_map)
      @sf_type_map = sf_type_map
      @type_map = sf_type_map.reject {|name, schema| ignored_column?(name, schema) }.
                              select {|name, schema| type_for(name, schema) }.
                              map {|name, schema| [name, type_for(name, schema)] }.
                              to_h
    end

    def active_record_column_defs
      type_map.map {|name, type| active_record_column_def(name, type) }
    end

    def columns
      @columns ||= type_map.keys
    end

    def updateable_columns
      @updateable_columns ||= sf_type_map.select {|_, type| type[:updateable?] }.keys
    end

    def serialized_columns
      @serialized_columns ||= type_map.select {|_, type| type.serialized }.keys
    end

    def array_columns
      @array_columns ||= type_map.select {|_, type| type.array }.keys
    end

    protected

    def type_for(sf_column_name, sf_column_schema)
      sf_type = sf_column_schema.fetch(:type)
      type = TYPES_MAP.fetch(sf_type) { warn "Unknown column type #{sf_type} for column #{sf_column_name}, ignoring it" }
      type.respond_to?(:call) ? type.call(sf_column_name, sf_column_schema) : type
    end

    def ignored_column?(sf_column_name, sf_column_schema)
      EXCLUDED_COLUMNS.include?(sf_column_name)
    end

    def active_record_column_def(column_name, type)
      ActiveRecordColumnDef.new(column_name, type.ar_type, type.ar_options)
    end
  end
end
