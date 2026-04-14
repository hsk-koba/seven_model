FactoryBot.define do
  factory :raw_book do
    sequence(:title) { |n| "Book #{n}"}
    author_id { create(:raw_user).id }
  end
end
