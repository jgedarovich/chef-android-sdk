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

def current_installed_extras
  installed_extras = [];
  #TODO: use sdk home from node attribute
  Dir[ "/usr/local/share/android-sdk/extras/**/source.properties" ].each do |properties_file|
    properties = Hash.new
    File.open(properties_file).each do |line|
        key,value = line.split(/=/)
        properties[key] = value
    end
    unless  properties.keys?("Pkg.Revision") &&
            properties.keys?("Extra.NameDisplay")
      raise "properties file is missing one of the required keys" 
    end
    #the below makes it look like what 'android sdk list --all' would spit out
    installed_extras.push(properties["Extra.NameDisplay"] +
      ", revision "+properties["Pkg.Revision"]
    )
  end
  installed_extras
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



