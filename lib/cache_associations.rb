require "cache_associations/version"

module CacheAssociations
  extend ActiveSupport::Concern

  UndefinedAssociationError = Class.new(StandardError)

  class_methods do
    def cache_association(name, **options, &cache_name_block)
      unless reflection = reflect_on_association(name)
        raise UndefinedAssociationError, "Undefined asscociation #{name}"
      end

      unless block_given?
        cache_name_block = lambda { [self.class.name, id, name, updated_at.to_i] }
      end

      register_cache_name_block(name, cache_name_block)
      options = Rails.cache.options.merge(options)

      define_method("cached_#{name}") do |*args, &block|
        break send(name) unless association_instance_get(name).nil?

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

    def cache_global_association(name, global_key = nil, **options)
      reflection = reflect_on_association(name)
      foreign_key = reflection.foreign_key

      if global_key.blank?
        global_key = reflection.klass.name
      end

      cache_name_block = lambda { [global_key, send(foreign_key)] }
      cache_association(name, **options, &cache_name_block)
    end
    
    def cache_method(name, **options, &cache_name_block)
      register_cache_name_block(name, cache_name_block)
      options = Rails.cache.options.merge(options)

      define_method("cached_#{name}") do |*args, &block|
        cache_name = cache_name_block.nil? ? default_cache_name(name) : instance_exec(&cache_name_block)
        Rails.cache.fetch(cache_name, **options) do
          break instance_exec(*args, &block) if !block.nil?
          
          send("#{name}", *args)
        end
      end
    end

    def has_cache_association?(name)
      cache_name_blocks.has_key?(name.to_sym)
    end

    def custom_cache_name?(name)
      !!cache_name_blocks[name.to_sym]
    end

    def cache_name_block(name)
      cache_name_blocks[name.to_sym]
    end

    private

    def register_cache_name_block(name, cache_name_block)
      warn "#{name} has been cached before." if has_cache_association?(name)
      cache_name_blocks[name] = cache_name_block
    end

    def cache_name_blocks
      @cache_name_blocks ||= {}
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
    return nil if !cache_name = cache_association_name(name)

    Rails.cache.delete(cache_name)
  end

  private

  def default_cache_name(name)
    [self.class.name, id, name.to_s, updated_at.to_i]
  end
end
