#
# Author:: Nuo Yan (<nuo@opscode.com>)
# Copyright:: Copyright (c) 2009 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef' / 'search' / 'query'

class ChefServerWebui::Search < ChefServerWebui::Application
  
  provides :html
  before :login_required 
    
  def index
    @s = Chef::Search::Query.new
    @search_indexes = @s.list_indexes
    render
  end

  def show
    begin
      @s = Chef::Search::Query.new
      query = params[:q].nil? ? "*:*" : (params[:q].empty? ? "*:*" : params[:q])
      @results = @s.search(params[:id], query)      
      @type = if params[:id].to_s == "node" || params[:id].to_s == "role" 
                params[:id]
              else 
                "databag" 
              end               
      @results = @results - @results.last(2)
      @results.each do |result|
        result.delete(nil)
      end
      @results
      render
    rescue StandardError => e
      @_message = { :error => "Unable to find the #{params[:id]}. (#{$!})" }
      @search_indexes = @s.list_indexes
      render :index
    end  
  end
  
end
