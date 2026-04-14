# frozen_string_literal: true

require "active_record"

module SevenModel
  # Helpers for using {SevenModel::Model} alongside ActiveRecord 7.2+.
  #
  # This file is optional: it +require+s Active Record. Load it when you use AR in loaders:
  #
  #   require "seven_model"
  #   require "seven_model/active_record"
  #
  module ActiveRecord
    class << self
      # Batch-loads rows by primary key column.
      #
      # Applies {https://api.rubyonrails.org/classes/ActiveRecord/QueryMethods.html#method-i-strict_loading ActiveRecord::QueryMethods#strict_loading}
      # by default so missing preloads raise (+ActiveRecord::StrictLoadingViolationError+).
      #
      # @param model_class [Class] an +ActiveRecord::Base+ subclass
      # @param ids [Array] unique values are loaded; order is not preserved (see {.records_by_ids_in_order})
      # @param id_column [Symbol] column name (must match the DB column used in +where+)
      # @param chunk_size [Integer, nil] when set to a positive integer, loads ids in slices of this size
      #   (several +WHERE id IN (...)+ queries). Use when the database limits bind variables (e.g. SQLite) or to cap memory.
      # @param strict_loading [Boolean, Symbol, nil] +true+ / +:all+ / +:n_plus_one_only+, or +false+ to disable
      # @return [Array<ActiveRecord::Base>]
      def records_by_ids(model_class, ids, id_column: :id, strict_loading: true, chunk_size: nil)
        raise ArgumentError, "model_class must be an ActiveRecord::Base subclass" unless model_class < ::ActiveRecord::Base

        id_list = Array(ids).uniq
        return [] if id_list.empty?

        validate_chunk_size!(chunk_size)
        unless chunk_size.nil?
          id_list.each_slice(chunk_size).flat_map do |chunk|
            load_ids_chunk(model_class, chunk, id_column: id_column, strict_loading: strict_loading)
          end
        else
          load_ids_chunk(model_class, id_list, id_column: id_column, strict_loading: strict_loading)
        end
      end

      # Like {.records_by_ids}, but returns rows in the same order as +ids+ (duplicates omitted in the query, then mapped).
      #
      # @param chunk_size [Integer, nil] passed to {.records_by_ids} when loading distinct ids
      # @return [Array<ActiveRecord::Base>] one row per id in +ids+; missing ids are skipped (+filter_map+).
      def records_by_ids_in_order(model_class, ids, id_column: :id, strict_loading: true, chunk_size: nil)
        id_list = Array(ids)
        return [] if id_list.empty?

        rows = records_by_ids(model_class, id_list.uniq, id_column: id_column, strict_loading: strict_loading, chunk_size: chunk_size)
        by_id = index_rows_by(rows, column: id_column)
        id_list.filter_map { |id| by_id[id] }
      end

      # Builds a hash +column value => row+ for use in +define_loader+ blocks (+index_by+ on the loader key).
      #
      # @param records [Enumerable]
      # @param column [Symbol] method name sent to each row (typically +:id+ or a foreign key)
      # @return [Hash{Object=>Object}]
      def index_rows_by(records, column: :id)
        Array(records).compact.index_by { |row| row.public_send(column) }
      end

      # Runs {https://api.rubyonrails.org/classes/ActiveRecord/Associations/Preloader.html ActiveRecord::Associations::Preloader}
      # for the given records (Rails 7.2+ API: keyword +records:+).
      #
      # @param records [Array<ActiveRecord::Base>, ActiveRecord::Base]
      # @param associations [Symbol, String, Array, Hash] same shape as +includes+
      # @return [Array] +records+ (after preloading side effects)
      def preload_associations!(records, associations, scope: nil, available_records: [], associate_by_default: true)
        flat = Array(records).flatten.compact
        return records if flat.empty? || associations.nil?

        ::ActiveRecord::Associations::Preloader.new(
          records: flat,
          associations: associations,
          scope: scope,
          available_records: available_records,
          associate_by_default: associate_by_default
        ).call

        records
      end

      # Stable id list for a relation (drops +ORDER BY+ when supported, then +distinct.pluck+).
      #
      # @param relation [ActiveRecord::Relation]
      # @param id_column [Symbol]
      # @return [Array]
      def ids_from_relation(relation, id_column: :id)
        raise ArgumentError, "relation must be an ActiveRecord::Relation" unless relation.is_a?(::ActiveRecord::Relation)

        rel = relation
        rel = rel.reorder(nil) if rel.respond_to?(:reorder)
        rel.distinct.pluck(id_column)
      end

      # Runs {SevenModel::Model::ClassMethods#bulk_load_and_compute} using ids taken from a relation.
      #
      # Typical wrapper on the computed model:
      #
      #   def self.from_users_scope(scope, with:)
      #     SevenModel::ActiveRecord.bulk_load_and_compute_from_relation(scope, self, with: with)
      #   end
      #
      # @param relation [ActiveRecord::Relation]
      # @param seven_model_class [Class] class including {SevenModel::Model}
      # @param with [Array, Symbol] dependency list passed to +bulk_load_and_compute+
      # @param id_column [Symbol] column plucked from +relation+
      # @param options [Hash] merged into +bulk_load_and_compute+ after +:ids+ (e.g. loader-specific keywords)
      # @return [Array] whatever +bulk_load_and_compute+ returns
      def bulk_load_and_compute_from_relation(relation, seven_model_class, with:, id_column: :id, **options)
        ids = options.delete(:ids) || ids_from_relation(relation, id_column: id_column)
        seven_model_class.bulk_load_and_compute(Array(with), **options, ids: ids)
      end

      private

      def validate_chunk_size!(chunk_size)
        return if chunk_size.nil?

        unless chunk_size.is_a?(Integer) && chunk_size.positive?
          raise ArgumentError, "chunk_size must be a positive Integer or nil, got #{chunk_size.inspect}"
        end
      end

      def load_ids_chunk(model_class, id_chunk, id_column:, strict_loading:)
        return [] if id_chunk.empty?

        scope = model_class.where(id_column => id_chunk)
        scope = apply_strict_loading(scope, strict_loading)
        scope.to_a
      end

      def apply_strict_loading(scope, strict_loading)
        return scope if strict_loading.nil? || strict_loading == false
        return scope unless scope.respond_to?(:strict_loading)

        scope.strict_loading(strict_loading == true ? true : strict_loading)
      end
    end
  end
end
