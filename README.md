# SevenModel

SevenModel is a universal batch loader which comes with a dependency-resolution algorithm.

- Thanks to the dependency resolution, it allows you to the following trifecta at once, without breaking abstraction.
  - Process information gathered from datasources (such as ActiveRecord) and return the derived one.
  - Prevent N+1 problem via batch loading.
  - Load only necessary data.
- Can load data from multiple datasources.
- Designed to be universal and datasource-independent.
  For example, you can gather data from both HTTP and ActiveRecord and return the derived one.

[日本語版README](README.ja.md)

## Why the rename?

SevenModel is the new name of ComputedModel. The project now targets **Rails 7+** as its baseline, and the new name makes that support policy explicit.

## Migration from ComputedModel

```ruby
# old
require "computed_model"
include ComputedModel::Model

# new
require "seven_model"
include SevenModel::Model
```

`ComputedModel` remains available as a compatibility alias in this release.

## Problems to solve

As models grow, they cannot simply return the database columns as-is.
Instead, we want to process information obtained from the database and return the derived value.

```ruby
class User < ApplicationRecord
  has_one :preference
  has_one :profile

  def display_name
    "#{preference.title} #{profile.name}"
  end
end
```

However, it can lead to N+1 without care.

```ruby
# N+1 problem!
User.where(id: friend_ids).map(&:display_name)
```

To solve the N+1 problem, we need to enumerate dependencies of `#display_name` and preload them.

```ruby
User.where(id: friend_ids).preload(:preference, :profile).map(&:display_name)
#                                  ^^^^^^^^^^^^^^^^^^^^^ breaks abstraction of display_name
```

This partially defeats the purpose of `#display_name`'s abstraction.

Computed solves the problem by connection the dependency-resolution to the batch loader.

```ruby
class User
  define_primary_loader :raw_user do ... end
  define_loader :preference do ... end
  define_loader :profile do ... end

  dependency :preference, :profile
  computed def display_name
    "#{preference.title} #{profile.name}"
  end
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'seven_model', '~> 0.3.0'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install seven_model

## Working example

```ruby
require 'seven_model'

# Consider them external sources (ActiveRecord or resources obtained via HTTP)
RawUser = Struct.new(:id, :name, :title)
Preference = Struct.new(:user_id, :name_public)

class User
  include SevenModel::Model

  attr_reader :id
  def initialize(raw_user)
    @id = raw_user.id
    @raw_user = raw_user
  end

  def self.list(ids, with:)
    bulk_load_and_compute(Array(with), ids: ids)
  end

  define_primary_loader :raw_user do |_subfields, ids:, **|
    # In ActiveRecord:
    # raw_users = RawUser.where(id: ids).to_a
    raw_users = [
      RawUser.new(1, "Tanaka Taro", "Mr. "),
      RawUser.new(2, "Yamada Hanako", "Dr. "),
    ].filter { |u| ids.include?(u.id) }
    raw_users.map { |u| User.new(u) }
  end

  define_loader :preference, key: -> { id } do |user_ids, _subfields, **|
    # In ActiveRecord:
    # Preference.where(user_id: user_ids).index_by(&:user_id)
    {
      1 => Preference.new(1, true),
      2 => Preference.new(2, false),
    }.filter { |k, _v| user_ids.include?(k) }
  end

  delegate_dependency :name, to: :raw_user
  delegate_dependency :title, to: :raw_user
  delegate_dependency :name_public, to: :preference

  dependency :name, :name_public
  computed def public_name
    name_public ? name : "Anonymous"
  end

  dependency :public_name, :title
  computed def public_name_with_title
    "#{title}#{public_name}"
  end
end

# You can only access the field you requested ahead of time
users = User.list([1, 2], with: [:public_name_with_title])
users.map(&:public_name_with_title) # => ["Mr. Tanaka Taro", "Dr. Anonymous"]
users.map(&:public_name) # => error (ForbiddenDependency)

users = User.list([1, 2], with: [:public_name_with_title, :public_name])
users.map(&:public_name_with_title) # => ["Mr. Tanaka Taro", "Dr. Anonymous"]
users.map(&:public_name) # => ["Tanaka Taro", "Anonymous"]

# In this case, preference will not be loaded.
users = User.list([1, 2], with: [:title])
users.map(&:title) # => ["Mr. ", "Dr. "]
```

## Active Record helpers (7.2+)

This gem depends on Active Support only at runtime. Optional helpers that **require Active Record** live under `SevenModel::ActiveRecord`. They autoload when you reference the constant (after `require "seven_model"`), or you can load explicitly:

```ruby
require "seven_model"
require "seven_model/active_record"
```

Highlights:

- **`records_by_ids` / `records_by_ids_in_order`** — batch `WHERE id IN (...)`, default **`strict_loading`** so missing `includes`/`preload` raises `ActiveRecord::StrictLoadingViolationError`. Pass **`chunk_size:`** to split large id lists (e.g. SQLite bind limits).
- **`preload_associations!`** — wraps `ActiveRecord::Associations::Preloader` (keyword `records:`) for loader bodies.
- **`ids_from_relation`** — stable id list from a relation (`reorder(nil)` + `distinct.pluck`).
- **`bulk_load_and_compute_from_relation`** — plucks ids from a relation, then calls `bulk_load_and_compute` on your wrapper class.
- **`index_rows_by`** — `column => row` hash for `define_loader` return values.

Example primary loader:

```ruby
define_primary_loader :raw_user do |_subfields, ids:, **|
  rows = SevenModel::ActiveRecord.records_by_ids_in_order(RawUser, ids, chunk_size: 500)
  rows.map { |r| User.new(r) }
end
```

Example loader returning a hash keyed by id:

```ruby
define_loader :things, key: -> { id } do |ids, _subfields, **|
  rows = Thing.where(user_id: ids)
  SevenModel::ActiveRecord.index_rows_by(rows, column: :user_id)
end
```

## Next read

- [Basic concepts and features](CONCEPTS.md)

## License

This library is distributed under MIT license.

Copyright (c) 2020 Masaki Hara

Copyright (c) 2020 Masayuki Izumi

Copyright (c) 2020 Wantedly, Inc.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wantedly/seven_model.
