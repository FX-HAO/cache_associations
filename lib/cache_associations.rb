require "cache_associations/version"

module CacheAssociations
  extend ActiveSupport::Concern

  UndefinedAssociationError = Class.new(StandardError)

  class_methods do
    def cache_association(name, **options, &cache_name_block)
      unless reflection = reflect_on_association(name)
        raise UndefinedAssociationError, "Undefined asscociation #{name}"
      end
      cache_association_names[name.to_sym] = cache_name_block
      options = Rails.cache.options.merge(options)

      define_method("cached_#{name}") do |*args, &block|
        cache_name = cache_name_block.nil? ? default_cache_name(name) : instance_exec(&cache_name_block)
        cache = Rails.cache.fetch(cache_name, **options) do
          break instance_exec(*args, &block) if !block.nil?

          if reflection.collection?
            send("#{name}", *args).to_a
          else
            send("#{name}", *args)
          end
        end

        if association_instance_get(name).nil?
          association = reflection.association_class.new(self, reflection)
          association.target = cache
          association_instance_set(name.to_sym, association)
        end

        cache
      end
    end

    def has_cache_association?(name)
      cache_association_names.has_key?(name.to_sym)
    end

    def custom_cache_name?(name)
      !!cache_association_names[name.to_sym]
    end

    def cache_name_block(name)
      cache_association_names[name.to_sym]
    end

    private

    def cache_association_names
      @cache_association_names ||= {}
    end
  end

  def cache_association_name(name)
    if !!cache_name_block = self.class.cache_name_block(name)
      instance_exec(&cache_name_block)
    elsif self.class.has_cache_association?(name)
      default_cache_name(name)
    else
      nil
    end
  end

  def clear_caching_on_association(name)
    return nil if !!cache_name = cache_association_name(name)

    Rails.cache.delete(cache_name)
  end

  private

  def default_cache_name(name)
    [self.class.name, id, name.to_s, updated_at.to_i]
  end
end
