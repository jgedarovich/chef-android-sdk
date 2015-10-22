actions :install
default_action :install

attribute :package_pattern, :kind_of => String, :name_attribute => true
attribute :android_home, :kind_of => String
attribute :android_bin, :kind_of => String
attribute :installed_packages, :kind_of => Array
attribute :available_packages, :kind_of => Array

def initialize(*args)
  super
  @action = :install
end
