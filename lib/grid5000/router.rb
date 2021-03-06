# Copyright (c) 2009-2011 Cyril Rohr, INRIA Rennes - Bretagne Atlantique
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Grid5000
  # Computes the URI to a specific path.
  # Takes into account the X-Api-Path-Prefix (additional prefix to add to URI
  # path), and X-Api-Mount-Path (subset of the API path to take out of the URI
  # path).
  class Router
    
    def initialize(where)
      @where = where
    end
    
    def call(params, request)
      self.class.uri_to(request, @where, :in, :absolute)
    end
    
    class << self
      def uri_to(request, path, in_or_out = :in, relative_or_absolute = :relative)
        api_version = if request.env['HTTP_X_API_VERSION'].blank?
          nil
        else
          File.join("/", (request.env['HTTP_X_API_VERSION'] || ""))
        end
        path_prefix = if request.env['HTTP_X_API_PATH_PREFIX'].blank?
          nil
        else
          File.join("/", (request.env['HTTP_X_API_PATH_PREFIX'] || ""))
        end
        mount_path = if request.env['HTTP_X_API_MOUNT_PATH'].blank?
          nil
        else
          File.join("/", (request.env['HTTP_X_API_MOUNT_PATH'] || ""))
        end
        uri = File.join("/", *[api_version, path_prefix, path].compact)
        uri.gsub!(mount_path, '') unless mount_path.nil?
        uri = "/" if uri.blank?
        if in_or_out == :out || relative_or_absolute == :absolute
          uri = URI.join(base_uri(in_or_out), uri).to_s
        end
        uri
      end

      # FIXME: move Rails.config to Grid5000.config
      def base_uri(in_or_out = :in)
        Rails.my_config("base_uri_#{in_or_out}".to_sym)
      end

    end
  end
end