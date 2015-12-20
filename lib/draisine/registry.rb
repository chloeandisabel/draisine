module Draisine
  class Registry
    attr_reader :models

    def initialize
      @models = {}
    end

    def find(name)
      models.fetch(name)
    end

    def register(model, name)
      models[name] = model
      models[model.name] ||= model
    end
  end

  def self.registry
    @registry ||= Registry.new
  end
end
