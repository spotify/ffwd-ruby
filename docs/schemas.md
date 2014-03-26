# Schemas

Some output plugins does not have a pre-defined output structure.

Consider when writing to kafka, you probably have a pre-defined internal data
structure for the messages being consumed from the queue.

For this purpose ffwd provides **schemas**.

These are pluggable components that knows how to dump the internal data
structures of ffwd into a specific structure of a specific *content type*.

The use of a specific schema looks like the following in the configuration
file.

```yaml
:output:
  - :type: "kafka"
    :schema: "my-schema-v01"
    :content_type: "application/json"
```

To list all availble schemas and content types, use **ffwd --schemas**.

This assumes that *my-schema-v01* is provided by a component which has been
loaded.

Writing a schema is very straight forward, it's only a matter of placing
a component under **lib/ffwd/schema/my_schema.rb** in your own ruby gem.

```ruby
require_relative 'ffwd/schema'

require 'json'

module FFWD::Schema
  module MySchema
    include FFWD::Schema

    module ApplicationJSON01
      def self.dump_metric m
        JSON.dump m.to_h
      end

      def self.dump_event e
        JSON.dump e.to_h
      end
    end

    module ApplicationJSON02
      def self.dump_metric m
        h = m.to_h
        h[:my_field] = 42
        JSON.dump h
      end

      def self.dump_event e
        JSON.dump e.to_h
      end
    end

    register_schema 'my-schema-v01', 'application/json', ApplicationJSON01
    register_schema 'my-schema-v02', 'application/json', ApplicationJSON02
  end
end
```
