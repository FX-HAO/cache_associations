require "cache_associations/version"

module CacheAssociations
  extend ActiveSupport::Concern

  UndefinedAssociationError = Class.new(StandardError)

  class_methods do
    def cache_association(name, &cache_name_block)
      unless reflection = reflect_on_association(name)
        raise UndefinedAssociationError, "Undefined asscociation #{name}"
      end

      define_method("cached_#{name}") do |*args, &block|
        cache_name = cache_name_block.nil? ? [self.class.name, id, name, updated_at.to_i] : instance_exec(&cache_name_block)
        cache = Rails.cache.fetch(cache_name) do
          send("#{name}", *args, &block)
        end

        if association_instance_get(name).nil?
          association = reflection.association_class.new(self, reflection)
          association.target = cache
          association_instance_set(name.to_sym, association)
        end

        cache
      end
    end
  end
end
