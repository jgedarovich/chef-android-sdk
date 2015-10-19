require 'chef/mixin/shell_out'
include Chef::Mixin::ShellOut

def whyrun_supported?
  true
end

def load_current_resource

  @current_resource = Chef::Resource::ComposerGlobalRequire.new(@new_resource.name)
  
  #a bit strange, but we only care about missing packages
  #get a list of installed packages on the system, and at what versions
  #get a list of available packages from android list sdk
  
  @current_resource.package_regex(@new_resource.package_package_regex)
  @current_resource.installed_packages(current_installed_packages)
  @current_resource

end

def current_installed_platform_tools
  installed_platform_tools = [];
  properties = Hash.new
  #TODO: use sdk home from node attribute
  #TODO: it might not be installed yet!
  File.open("/usr/local/share/android-sdk/platform-tools/source.properties") do |line|
      key,value = line.split(/=/)
      properties[key] = value
  end
  unless  properties.keys?("Pkg.Revision")
    raise "properties file is missing one of the required keys" 
  end
  #the below makes it look like what 'android sdk list --all' would spit out
  installed_platform_tools.push("Android SDK Platform-tools, revision " + properties["Pkg.Revision"])
  installed_platform_tools
end

action :install do
#get a list of installed packages on the system
  #get a list of available packages to install from
  #regex of what to install
  #the list to install = 
  # (already installed) set difference ( list of packages that  match regex from 'available to install')

  #foreach list to install
    #make a filter
    #install using filter / expect
end



