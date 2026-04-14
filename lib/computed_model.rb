# frozen_string_literal: true

require "seven_model/version"
require "seven_model/plan"
require "seven_model/dep_graph"
require "seven_model/model"

# SevenModel is a universal batch loader which comes with a dependency-resolution algorithm.
#
# - Thanks to the dependency resolution, it allows you to the following trifecta at once, without breaking abstraction.
#   - Process information gathered from datasources (such as ActiveRecord) and return the derived one.
#   - Prevent N+1 problem via batch loading.
#   - Load only necessary data.
# - Can load data from multiple datasources.
# - Designed to be universal and datasource-independent.
#   For example, you can gather data from both HTTP and ActiveRecord and return the derived one.
#
# See {SevenModel::Model} for basic usage.
module SevenModel
  autoload :ActiveRecord, "seven_model/active_record"

  # An error raised when you tried to read from a loaded/computed attribute,
  # but that attribute isn't loaded by the batch loader.
  class NotLoaded < StandardError; end

  # An error raised when you tried to read from a loaded/computed attribute,
  # but that attribute isn't listed in the dependencies list.
  class ForbiddenDependency < StandardError; end

  # An error raised when the dependency graph contains a cycle.
  class CyclicDependency < StandardError; end

  # Normalizes dependency list as a hash.
  #
  # Normally you don't need to call it directly.
  # {SevenModel::Model::ClassMethods#dependency}, {SevenModel::Model::ClassMethods#bulk_load_and_compute}, and
  # {SevenModel::NormalizableArray#normalized} will internally use this function.
  #
  # @param deps [Array<(Symbol, Hash)>, Hash, Symbol] dependency list
  # @return [Hash{Symbol=>Array}] normalized dependency hash
  # @raise [RuntimeError] if the dependency list contains values other than Symbol or Hash
  # @example
  #   SevenModel.normalize_dependencies([:foo, :bar])
  #   # => { foo: [true], bar: [true] }
  #
  # @example
  #   SevenModel.normalize_dependencies([:foo, bar: :baz])
  #   # => { foo: [true], bar: [true, :baz] }
  #
  # @example
  #   SevenModel.normalize_dependencies(foo: -> (subfields) { true })
  #   # => { foo: [#<Proc:...>] }
  def self.normalize_dependencies(deps)
    normalized = {}
    deps = [deps] if deps.is_a?(Hash)
    Array(deps).each do |elem|
      case elem
      when Symbol
        normalized[elem] ||= [true]
      when Hash
        elem.each do |k, v|
          v = [v] if v.is_a?(Hash)
          normalized[k] ||= []
          normalized[k].push(*Array(v))
          normalized[k].push(true) if v == []
        end
      else; raise "Invalid dependency: #{elem.inspect}"
      end
    end
    normalized
  end

  # Removes `nil`, `true` and `false` from the given array.
  #
  # Normally you don't need to call it directly.
  # {SevenModel::Model::ClassMethods#define_loader},
  # {SevenModel::Model::ClassMethods#define_primary_loader}, and
  # {SevenModel::NormalizableArray#normalized} will internally use this function.
  #
  # @param subfields [Array] subfield selector list
  # @return [Array] the filtered one
  # @example
  #   SevenModel.filter_subfields([false, {}, true, nil, { foo: :bar }])
  #   # => [{}, { foo: :bar }]
  def self.filter_subfields(subfields)
    subfields.select { |x| x && x != true }
  end

  # Convenience class to easily access normalized version of dependencies.
  #
  # You don't need to directly use it.
  #
  # - {SevenModel::Model#current_subfields} returns NormalizableArray.
  # - Procs passed to {SevenModel::Model::ClassMethods#dependency} will receive NormalizeArray.
  class NormalizableArray < Array
    # Returns the normalized hash of the dependencies.
    # @return [Hash{Symbol=>Array}] the normalized hash of the dependencies
    # @raise [RuntimeError] if the list isn't valid as a dependency list.
    #   See {SevenModel.normalize_dependencies} for details.
    def normalized
      @normalized ||= SevenModel.normalize_dependencies(SevenModel.filter_subfields(self))
    end
  end
end


ComputedModel = SevenModel unless defined?(ComputedModel)
