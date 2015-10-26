require 'chef/mixin/shell_out'
include Chef::Mixin::ShellOut
include AndroidSdkHelper

def whyrun_supported?
  true
end

def load_current_resource
  @current_resource = Chef::Resource::AndroidSdkInstallPackages.new(@new_resource.name)
  #TODO: use shell_out
end

action :install do
  puts "        - Install Android SDK package: #{@new_resource.name}"
  install_packages(@new_resource.name, @new_resource.android_home, @new_resource.android_bin)
end



