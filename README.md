# CacheAssociations
[![Gem Version](https://badge.fury.io/rb/cache_associations.svg)](https://badge.fury.io/rb/cache_associations)
[![Dependency Status](https://gemnasium.com/badges/github.com/FX-HAO/cache_associations.svg)](https://gemnasium.com/github.com/FX-HAO/cache_associations)

CacheAssociations is a simple cache implementation to make Low-Level caching collaborate with Association caching.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cache_associations'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cache_associations

## Usage

```ruby
class User < ApplicationRecord
  include CacheAssociations

  has_one :profile
  cache_association :profile do 
    # put your cache name here
    [self.class.name, id, 'profile', update_at.to_i]
  end
end

class Profile < ApplicationRecord
  belongs_to :user, touch: true
end
```

The `cache_association` defines a method `cached_profile` to fetch data from the cache store.
You may also specify additional options via the options argument, it's the same as `ActiveSupport::Cache::Store#fetch`, 
such as setting `:expires_in` will set an expiration time on the cache.
And `cache_association` accepts an optional block to define the cache name, it's `[self.class.name, id, name, updated_at.to_i]` in default.

```ruby
irb> u = User.take
irb> u.cached_profile # fetch from the cache store
irb> u.profile # fetch the cached version
irb> u.profile.reload # refetch from the database
  Profile Load (1.4ms) SELECT  "profiles".* FROM "profiles" WHERE "profiles"."user_id" = $1 LIMIT $2  [["id", 1], ["LIMIT", 1]]
```

You may customize what the data you cached, the cached method accepts an optional block that determines how to cache data. 
But it will break the original association, so you should be careful with this feature.

```
irb> u = User.take
irb> u.cached_profile do "gotcha" end
=> "gotcha"
irb> u.profile # it breaks
(Object doesn't support #inspect)
=> 
irb> u.profile.reload # restore
  Profile Load (1.4ms) SELECT  "profiles".* FROM "profiles" WHERE "profiles"."user_id" = $1 LIMIT $2  [["id", 1], ["LIMIT", 1]]
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/FX-HAO/cache_associations. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CacheAssociations project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/cache_associations/blob/master/CODE_OF_CONDUCT.md).
