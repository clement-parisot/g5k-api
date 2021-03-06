# Copyright (c) 2014-2016 Anirvan BASU, INRIA Rennes - Bretagne Atlantique
#
# Licensed under the Apache License, environment 2.0 (the "License");
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

require 'spec_helper'

describe EnvironmentsController do
  render_views
  
  describe "GET /environments/{{id}}" do
    it "should fail if the environment does not exist" do
      get :show, :id => "doesnotexist", :format => :json
      response.status.should == 404
      assert_vary_on :accept
      response.body.should == "Cannot find resource /environments/doesnotexist"
    end
    
    it "should return the environment with the correct md5 hash" do
      get :show, :id => "sid-x64-base-1.0", :format => :json
      response.status.should == 200
      assert_media_type(:json)
      assert_vary_on :accept
      assert_allow :get
      json["uid"].should == "sid-x64-base-1.0"
      json["file"]["md5"].should == "e39be32c087f0c9777fd0b0ad7d12050"
      json["type"].should == "environment"
    end
  end # describe "GET /environments/{{id}}"
  
  describe "GET /sites/{{site_id}}/environments/{{id}}" do
    it "should return the environment in a site with the correct md5 hash" do
      get :index, :site_id => "rennes", :id => "sid-x64-base-1.0", :format => :json
      response.status.should == 200
      assert_media_type(:json)
      assert_vary_on :accept
      assert_allow :get
      # In this case, the body of the response is an array of hashes (json elements). 
      # In the test case, just choose the first element of the array.
      first = json["items"][0]
      first["uid"].should == "sid-x64-base-1.0"
      first["file"]["md5"].should == "e39be32c087f0c9777fd0b0ad7d12050"
      first["type"].should == "environment"
    end
    
    it "should return 500 if the site does not exist" do
      get :index, :site_id => "does/not/exist", :id => "sid-x64-base-1.0", :format => :json
      response.status.should == 500
    end
  end # describe "GET /sites/{{site_id}}/environments/{{id}}"
  
end
