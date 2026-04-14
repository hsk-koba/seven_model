# frozen_string_literal: true

require "spec_helper"
require "support/models/raw_user"
require "support/models/raw_book"

RSpec.describe ComputedModel::ActiveRecord do
  let!(:raw_user1) { create(:raw_user, name: "Alice") }
  let!(:raw_user2) { create(:raw_user, name: "Bob") }

  describe ".records_by_ids" do
    it "returns rows for the given ids" do
      rows = described_class.records_by_ids(RawUser, [raw_user1.id, raw_user2.id])
      expect(rows.map(&:id)).to contain_exactly(raw_user1.id, raw_user2.id)
    end

    it "returns an empty array for an empty id list" do
      expect(described_class.records_by_ids(RawUser, [])).to eq([])
    end

    it "marks rows strict_loading by default" do
      u = described_class.records_by_ids(RawUser, [raw_user1.id]).first
      expect(u.strict_loading?).to be(true)
    end

    it "raises StrictLoadingViolationError when an association was not preloaded" do
      u = described_class.records_by_ids(RawUser, [raw_user1.id]).first
      expect { u.authored_books.load }.to raise_error(::ActiveRecord::StrictLoadingViolationError)
    end

    it "does not apply strict_loading when strict_loading: false" do
      u = described_class.records_by_ids(RawUser, [raw_user1.id], strict_loading: false).first
      expect(u.strict_loading?).to be(false)
    end

    it "rejects non-AR model classes" do
      expect do
        described_class.records_by_ids(String, [1])
      end.to raise_error(ArgumentError, /ActiveRecord::Base/)
    end
  end

  describe ".records_by_ids_in_order" do
    it "preserves id order and duplicates in the result shape" do
      ids = [raw_user2.id, raw_user1.id, raw_user2.id]
      rows = described_class.records_by_ids_in_order(RawUser, ids)
      expect(rows.map(&:id)).to eq([raw_user2.id, raw_user1.id, raw_user2.id])
    end

    it "matches non-chunked results when chunk_size is set" do
      ids = [raw_user2.id, raw_user1.id, raw_user2.id]
      expect(described_class.records_by_ids_in_order(RawUser, ids, chunk_size: 1).map(&:id)).to eq(
        described_class.records_by_ids_in_order(RawUser, ids).map(&:id)
      )
    end
  end

  describe ".records_by_ids chunk_size" do
    it "returns the same rows as a single query when chunk_size splits the id list" do
      ids = [raw_user1.id, raw_user2.id]
      full = described_class.records_by_ids(RawUser, ids)
      chunked = described_class.records_by_ids(RawUser, ids, chunk_size: 1)
      expect(chunked.map(&:id)).to match_array(full.map(&:id))
    end

    it "rejects invalid chunk_size" do
      expect do
        described_class.records_by_ids(RawUser, [raw_user1.id], chunk_size: 0)
      end.to raise_error(ArgumentError, /chunk_size/)

      expect do
        described_class.records_by_ids(RawUser, [raw_user1.id], chunk_size: "1")
      end.to raise_error(ArgumentError, /chunk_size/)
    end
  end

  describe ".index_rows_by" do
    it "indexes rows by the given column" do
      rows = described_class.records_by_ids(RawUser, [raw_user1.id, raw_user2.id], strict_loading: false)
      h = described_class.index_rows_by(rows, column: :id)
      expect(h[raw_user1.id].name).to eq("Alice")
      expect(h[raw_user2.id].name).to eq("Bob")
    end
  end

  describe ".preload_associations!" do
    it "preloads associations so strict_loading records can traverse them" do
      create(:raw_book, author_id: raw_user1.id)
      u = described_class.records_by_ids(RawUser, [raw_user1.id]).first
      described_class.preload_associations!(u, :authored_books)
      expect { u.authored_books.load }.not_to raise_error
      expect(u.authored_books).not_to be_empty
    end
  end

  describe ".ids_from_relation" do
    it "returns distinct ids and strips order for pluck" do
      rel = RawUser.where(id: [raw_user1.id, raw_user2.id]).order(name: :desc)
      expect(described_class.ids_from_relation(rel)).to contain_exactly(raw_user1.id, raw_user2.id)
    end

    it "rejects non-relations" do
      expect { described_class.ids_from_relation([]) }.to raise_error(ArgumentError, /ActiveRecord::Relation/)
    end
  end

  describe ".bulk_load_and_compute_from_relation" do
    let(:computed_user_class) do
      Class.new do
        def self.name
          "ComputedUser"
        end

        include ComputedModel::Model

        attr_reader :id

        def initialize(raw_user)
          @id = raw_user.id
          @raw_user = raw_user
        end

        define_primary_loader :raw_user do |_subfields, ids:, **|
          ComputedModel::ActiveRecord.records_by_ids_in_order(RawUser, ids, strict_loading: false).map { |r| new(r) }
        end

        delegate_dependency :name, to: :raw_user
      end
    end

    it "runs bulk_load_and_compute with ids from a relation" do
      rel = RawUser.where(id: raw_user1.id)
      users = described_class.bulk_load_and_compute_from_relation(rel, computed_user_class, with: [:name])
      expect(users.map(&:name)).to eq(["Alice"])
    end

    it "honours explicit ids: in options over the relation" do
      rel = RawUser.where(id: raw_user1.id)
      users = described_class.bulk_load_and_compute_from_relation(
        rel,
        computed_user_class,
        with: [:name],
        ids: [raw_user2.id]
      )
      expect(users.map(&:name)).to eq(["Bob"])
    end
  end
end
