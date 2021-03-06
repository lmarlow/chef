#
# Author:: Daniel DeLeo (<dan@kallistec.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
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


require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "spec_helper"))
describe Chef::Provider::Git do
  
  before(:each) do
    @resource = Chef::Resource::Git.new("web2.0 app")
    @resource.repository "git://github.com/opscode/chef.git"
    @resource.destination "/my/deploy/dir"
    @resource.revision "d35af14d41ae22b19da05d7d03a0bafc321b244c"
    @node = Chef::Node.new
    @provider = Chef::Provider::Git.new(@node, @resource)
  end
  
  context "determining the revision of the currently deployed checkout" do
    
    before do
      @stdout = mock("standard out")
      @stderr = mock("standard error")
      @exitstatus = mock("exitstatus")
    end
    
    it "sets the current revison to nil if the deploy dir does not exist" do
      ::File.should_receive(:exist?).with("/my/deploy/dir/.git").and_return(false)
      @provider.find_current_revision.should be_nil
    end
    
    it "determines the current revision when there is one" do
      ::File.should_receive(:exist?).with("/my/deploy/dir/.git").and_return(true)
      ::File.should_receive(:directory?).with("/my/deploy/dir").and_return(true)
      ::Dir.should_receive(:chdir).with("/my/deploy/dir").and_yield
      @stderr.stub!(:string).and_return('')
      @stdout.stub!(:string).and_return("9b4d8dc38dd471246e7cfb1c3c1ad14b0f2bee13\n")
      @exitstatus.stub!(:exitstatus).and_return(0)
      @provider.should_receive(:popen4).and_yield("fake-pid","no-stdin", @stdout, @stderr).and_return(@exitstatus)
      @provider.find_current_revision.should eql("9b4d8dc38dd471246e7cfb1c3c1ad14b0f2bee13")
    end
  
    it "gives the current revision as nil when there is no current revision" do
      ::File.should_receive(:exist?).with("/my/deploy/dir/.git").and_return(true)
      ::File.should_receive(:directory?).with("/my/deploy/dir").and_return(true)
      ::Dir.should_receive(:chdir).with("/my/deploy/dir").and_yield
      @stderr.stub!(:string).and_return"fatal: Not a git repository (or any of the parent directories): .git"
      @stdout.stub!(:string).and_return("")
      @exitstatus.stub!(:exitstatus).and_return(128)
      @provider.should_receive(:popen4).and_yield("fake-pid","no-stdin", @stdout, @stderr).and_return(@exitstatus)
      @provider.find_current_revision.should be_nil
    end
  end
  
  it "creates a current_resource with the currently deployed revision when a clone exists in the destination dir" do
    @provider.stub!(:find_current_revision).and_return("681c9802d1c62a45b490786c18f0b8216b309440")
    @provider.load_current_resource
    @provider.current_resource.name.should eql(@resource.name)
    @provider.current_resource.revision.should eql("681c9802d1c62a45b490786c18f0b8216b309440")
  end
  
  it "keeps the node and resource passed to it on initialize" do
    @provider.node.should equal(@node)
    @provider.new_resource.should equal(@resource)
  end
  
  context "resolving revisions to a SHA" do
    
    before do
      @stderr = mock("standard error")
      @stderr.stub!(:string).and_return("")
      @stdout = mock("std out")
      @exitstatus = mock("exitstatus")
      @exitstatus.stub!(:exitstatus).and_return(0)
      @git_ls_remote = "git ls-remote git://github.com/opscode/chef.git "
    end
    
    it "returns resource.revision as is if revision is already a full SHA" do
      @provider.revision_sha.should eql("d35af14d41ae22b19da05d7d03a0bafc321b244c")
    end

    it "converts resource.revision from a tag to a SHA" do
      @resource.revision "v1.0"
      @stdout.stub!(:string).and_return("503c22a5e41f5ae3193460cca044ed1435029f53\trefs/heads/0.8-alpha\n")
      @provider.should_receive(:popen4).with(@git_ls_remote + "v1.0", {:cwd => instance_of(String)}).
                                        and_yield("pid","stdin",@stdout,@stderr).
                                        and_return(@exitstatus)
      @provider.revision_sha.should eql("503c22a5e41f5ae3193460cca044ed1435029f53")
    end
    
    it "raises a runtime error if you try to deploy from ``origin''" do
      @resource.revision("origin")
      lambda {@provider.revision_sha}.should raise_error(RuntimeError)
    end
  
    it "raises a runtime error if the revision can't be resolved to any revision" do
      @resource.revision "FAIL, that's the revision I want"
      @stdout.stub!(:string).and_return("\n")
      @provider.should_receive(:popen4).and_yield("pid","stdin",@stdout,@stderr).and_return(@exitstatus)
      lambda {@provider.revision_sha}.should raise_error(RuntimeError)
    end
    
    it "gives the latest HEAD revision SHA if nothing is specified" do
      lots_of_shas =  "28af684d8460ba4793eda3e7ac238c864a5d029a\tHEAD\n"+
                      "503c22a5e41f5ae3193460cca044ed1435029f53\trefs/heads/0.8-alpha\n"+
                      "28af684d8460ba4793eda3e7ac238c864a5d029a\trefs/heads/master\n"+
                      "c44fe79bb5e36941ce799cee6b9de3a2ef89afee\trefs/tags/0.5.2\n"+
                      "14534f0e0bf133dc9ff6dbe74f8a0c863ff3ac6d\trefs/tags/0.5.4\n"+
                      "d36fddb4291341a1ff2ecc3c560494e398881354\trefs/tags/0.5.6\n"+
                      "9e5ce9031cbee81015de680d010b603bce2dd15f\trefs/tags/0.6.0\n"+
                      "9b4d8dc38dd471246e7cfb1c3c1ad14b0f2bee13\trefs/tags/0.6.2\n"+
                      "014a69af1cdce619de82afaf6cdb4e6ac658fede\trefs/tags/0.7.0\n"+
                      "fa8097ff666af3ce64761d8e1f1c2aa292a11378\trefs/tags/0.7.2\n"+
                      "44f9be0b33ba5c10027ddb030a5b2f0faa3eeb8d\trefs/tags/0.7.4\n"+
                      "d7b9957f67236fa54e660cc3ab45ffecd6e0ba38\trefs/tags/0.7.8\n"+
                      "b7d19519a1c15f1c1a324e2683bd728b6198ce5a\trefs/tags/0.7.8^{}\n"+
                      "ebc1b392fe7e8f0fbabc305c299b4d365d2b4d9b\trefs/tags/chef-server-package"
      @resource.revision ''
      @stdout.stub!(:string).and_return(lots_of_shas)
      @provider.should_receive(:popen4).and_yield("pid","stdin",@stdout,@stderr).and_return(@exitstatus)
      @provider.revision_sha.should eql("28af684d8460ba4793eda3e7ac238c864a5d029a")
    end
  end
  
  it "responds to :revision_slug as an alias for revision_sha" do
    @provider.should respond_to(:revision_slug)
  end
  
  it "runs a clone command with default git options" do
    @resource.user "deployNinja"
    @resource.ssh_wrapper "do_it_this_way.sh"
    expected_cmd = 'git clone  git://github.com/opscode/chef.git /my/deploy/dir'
    @provider.should_receive(:run_command).with(:command => expected_cmd, :user => "deployNinja", 
                                                :environment =>{"GIT_SSH"=>"do_it_this_way.sh"})
    @provider.clone
  end
  
  it "compiles a clone command using --depth for shallow cloning" do
    @resource.depth 5
    expected_cmd = 'git clone --depth 5 git://github.com/opscode/chef.git /my/deploy/dir'
    @provider.should_receive(:run_command).with(:command => expected_cmd)
    @provider.clone
  end
  
  it "compiles a clone command with a remote other than ``origin''" do
    @resource.remote "opscode"
    expected_cmd = 'git clone -o opscode git://github.com/opscode/chef.git /my/deploy/dir'
    @provider.should_receive(:run_command).with(:command => expected_cmd)
    @provider.clone
  end
  
  it "runs a checkout command with default options" do
    expected_cmd = 'git checkout -b deploy d35af14d41ae22b19da05d7d03a0bafc321b244c'
    @provider.should_receive(:run_command).with(:command => expected_cmd, :cwd => "/my/deploy/dir")
    @provider.checkout
  end
  
  it "runs an enable_submodule command" do
    @resource.enable_submodules true
    expected_cmd = "git submodule init && git submodule update"
    @provider.should_receive(:run_command).with(:command => expected_cmd, :cwd => "/my/deploy/dir")
    @provider.enable_submodules
  end
  
  it "does nothing for enable_submodules if resource.enable_submodules #=> false" do
    @provider.should_not_receive(:run_command)
    @provider.enable_submodules
  end
  
  it "runs a sync command with default options" do
    expected_cmd = "git fetch origin --tags && git reset --hard d35af14d41ae22b19da05d7d03a0bafc321b244c"
    @provider.should_receive(:run_command).with(:command=>expected_cmd, :cwd=> "/my/deploy/dir")
    @provider.sync
  end
  
  it "compiles a sync command using remote tracking branches when remote is not ``origin''" do
    @resource.remote "opscode"
    expected_cmd =  "git config remote.opscode.url git://github.com/opscode/chef.git && " +
                    "git config remote.opscode.fetch +refs/heads/*:refs/remotes/opscode/* && " +
                    "git fetch opscode --tags && git reset --hard d35af14d41ae22b19da05d7d03a0bafc321b244c"
    @provider.should_receive(:run_command).with(:command => expected_cmd, :cwd => "/my/deploy/dir")
    @provider.sync
  end
  
  it "does a checkout running the clone command then running the after clone command from the destination dir" do
    @provider.should_receive(:clone)
    @provider.should_receive(:checkout)
    @provider.should_receive(:enable_submodules)
    @resource.should_receive(:updated=).at_least(1).times.with(true)
    @provider.action_checkout
  end

  it "does a sync by running the sync command" do
    ::File.stub!(:exist?).with("/my/deploy/dir").and_return(true)
    ::Dir.stub!(:entries).and_return(['.','..',"lib", "spec"])
    @provider.should_receive(:sync)
    @resource.should_receive(:updated=).at_least(1).times.with(true)
    @provider.action_sync
  end
  
  it "does a checkout instead of sync if the deploy directory doesn't exist" do
    ::File.stub!(:exist?).with("/my/deploy/dir").and_return(false)
    @provider.should_receive(:action_checkout)
    @provider.should_not_receive(:run_command)
    @resource.should_receive(:updated=).at_least(1).times.with(true)
    @provider.action_sync
  end
  
  it "does a checkout instead of sync if the deploy directory is empty" do
    ::File.stub!(:exist?).with("/my/deploy/dir").and_return(true)
    ::Dir.stub!(:entries).with("/my/deploy/dir").and_return([".",".."])
    @provider.stub!(:sync_command).and_return("huzzah!")
    @provider.should_receive(:action_checkout)
    @provider.should_not_receive(:run_command).with(:command => "huzzah!", :cwd => "/my/deploy/dir")
    @resource.should_receive(:updated=).at_least(1).times.with(true)
    @provider.action_sync
  end
  
  it "does an export by cloning the repo then removing the .git directory" do
    @provider.should_receive(:action_checkout)
    FileUtils.should_receive(:rm_rf).with(@resource.destination + "/.git")
    @resource.should_receive(:updated=).at_least(1).times.with(true)
    @provider.action_export
  end
  
end
