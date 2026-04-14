# frozen_string_literal: true

RSpec.describe "SevenModel::VERSION" do
  it "has a version number" do
    expect(SevenModel::VERSION).not_to be_nil
  end

  it "keeps backward compatibility alias" do
    expect(defined?(ComputedModel)).to eq("constant")
    expect(ComputedModel::VERSION).to eq(SevenModel::VERSION)
  end
end
