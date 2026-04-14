# frozen_string_literal: true

require 'support/models/application_record'

class RawUser < ApplicationRecord
  self.table_name = "users"

  has_many :authored_books, class_name: "RawBook", foreign_key: :author_id, inverse_of: :author
end
