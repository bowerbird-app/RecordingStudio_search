# frozen_string_literal: true

module RecordingStudioSearch
  # Per-model WHEREs other gems register so search can drop rows inside the
  # statement that applies LIMIT. The block receives the relation search
  # already built (including the Accessible scope) and returns it narrowed
  # with +where+. The original relation is kept and the filter is ANDed, so
  # a filter cannot unscope access or otherwise widen the hit set.
  #
  # Register from +to_prepare+. The same source line replaces its previous
  # block on reload instead of stacking a second copy.
  module ResultFilters
    SHAPE = %i[
      order limit offset select group having distinct
      includes preload eager_load annotate
    ].freeze

    module_function

    def register(model, &block)
      raise ArgumentError, "register_result_filter expects a model class" unless model.is_a?(Class)
      raise ArgumentError, "register_result_filter expects a block" unless block

      name = model.name
      raise ArgumentError, "register_result_filter expects a named model" if name.blank?

      list = (registry[name] ||= [])
      index = list.index { |existing| same_filter?(existing, block) }
      if index
        list[index] = block
      else
        list << block
      end
      block
    end

    def apply(model_or_relation)
      relation = relation_for(model_or_relation)
      filters = registry[relation.klass.name]
      return relation if filters.blank?

      filters.reduce(relation) { |current, filter| narrow(current, filter) }
    end

    def registered_for?(model_or_relation)
      registry[model_name(model_or_relation)].present?
    end

    # Id subquery for the vector nearest-neighbour statement. The relation
    # should already be +apply+'d. Kept unloaded so the filter stays inside LIMIT.
    def ids_for(relation)
      relation.except(
        :order, :includes, :preload, :eager_load, :limit, :offset, :group, :having
      ).reselect(:id)
    end

    def count_for(model)
      Array(registry[model_name(model)]).size
    end

    def reset!
      @registry = {}
    end

    def registry
      @registry ||= {}
    end

    def relation_for(model_or_relation)
      return model_or_relation if model_or_relation.is_a?(ActiveRecord::Relation)
      return model_or_relation.all if model_or_relation.respond_to?(:all)

      raise ArgumentError, "result filter expected an ActiveRecord model or relation"
    end

    def model_name(model_or_relation)
      return model_or_relation.name if model_or_relation.is_a?(Class)

      model_or_relation.klass.name
    end

    def narrow(relation, filter)
      filtered = filter.call(relation)
      unless filtered.is_a?(ActiveRecord::Relation) && filtered.klass == relation.klass
        raise ArgumentError, "result filter for #{relation.klass.name} must return a #{relation.klass.name} relation"
      end

      intersect(relation, filtered)
    end

    # AND the filter onto the relation search already has. A plain +where+
    # stays on that relation, so order and binds are untouched. When the
    # returned relation drops order or limit, strip those and AND the where
    # clauses. +merge+ is not used: it can replace an equality on the same
    # column and would drop the authorized-id scope.
    def intersect(relation, filtered)
      relation.and(filtered)
    rescue ArgumentError => e
      raise unless structurally_incompatible?(e)

      left = without_shape(relation)
      right = without_shape(filtered)
      left = left.joins(right.joins_values) if right.joins_values.any? && left.joins_values.empty?
      restore_shape(relation, left.and(right))
    end

    def structurally_incompatible?(error)
      error.message.include?("structurally compatible")
    end

    def without_shape(relation)
      relation.except(*SHAPE)
    end

    def restore_shape(original, relation)
      relation = relation.reorder(original.order_values) if original.order_values.any?
      relation = relation.limit(original.limit_value) unless original.limit_value.nil?
      relation = relation.offset(original.offset_value) unless original.offset_value.nil?
      relation = relation.annotate(*original.annotate_values) if original.annotate_values.any?
      relation
    end

    def same_filter?(existing, block)
      return true if existing.equal?(block)

      location = block.source_location
      location && existing.source_location == location
    end

    private_class_method :registry, :relation_for, :model_name, :narrow, :intersect,
                         :structurally_incompatible?, :without_shape, :restore_shape,
                         :same_filter?
  end
end
