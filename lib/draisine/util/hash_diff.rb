module Draisine
  HashDiff = Struct.new(:added, :removed, :changed, :unchanged) do
    def self.diff(hash1, hash2, equality = -> (a, b) { a == b })
      unless hash1.respond_to?(:key?) && hash2.respond_to?(:key?)
        fail ArgumentError, "both arguments should be hashes"
      end

      added = []
      removed = []
      changed = []
      unchanged = []

      (hash1.keys | hash2.keys).each do |key|
        if hash1.key?(key) && hash2.key?(key)
          if equality.call(hash1[key], hash2[key])
            unchanged << key
          else
            changed << key
          end
        elsif hash1.key?(key)
          removed << key
        else
          added << key
        end
      end

      new(added, removed, changed, unchanged)
    end

    def self.sf_diff(hash1, hash2)
      diff(hash1, hash2, SalesforceComparisons.method(:salesforce_equals?))
    end

    def diff_keys
      changed | added | removed
    end
  end

end
