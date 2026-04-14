# frozen_string_literal: true

require 'support/models/application_record'

class RawBook < ApplicationRecord
  self.table_name = "books"

  belongs_to :author, class_name: "RawUser", foreign_key: :author_id, inverse_of: :authored_books
end
