# frozen_string_literal: true

require "seven_model/version"

module ComputedModel
  VERSION = SevenModel::VERSION unless const_defined?(:VERSION)
end
