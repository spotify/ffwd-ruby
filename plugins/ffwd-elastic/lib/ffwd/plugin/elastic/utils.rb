# $LICENSE
# Copyright 2013-2014 Spotify AB. All rights reserved.
#
# The contents of this file are licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

module FFWD::Plugin::Elastic
  module Utils
    def self.make_bulk_body(metrics)
      body = []

      metrics.each do |metric|
        body << {
            :'index' => {
            }
        }
        body << {
            :'key' => metric.key,
            :'value' => metric.value,
            :'host' => metric.host,
            :'attributes' => metric.attributes,
            :'tags' => metric.tags,
            :'@timestamp' => metric.time.iso8601,
            :'@version' => 1
        }
      end

      body
    end


    def self.make_template_body(index)
      body = {
          :'template' => '%s-*' % [index],
          :'settings' => {
              :'index.refresh_interval' => '5s'
          },
          :'mappings' => {
              :'_default_' => {
                  :'dynamic_templates' => [
                      {
                          :'string_fields' => {
                              :'match' => '*',
                              :'match_mapping_type' => 'string',
                              :'mapping' => {
                                  :'type' => 'string',
                                  :'index' => 'not_analyzed',
                                  :'omit_norms' => true
                              }
                          }
                      }
                  ],
                  :'properties' => {
                      :'value' => {
                          :'type' => 'double',
                      }
                  }
              }
          }
      }

      body
    end
  end
end
