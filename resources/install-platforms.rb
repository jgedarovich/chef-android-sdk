actions :install
default_action :install

attribute :package_regex, :kind_of => String, :name_attribute => true

def initialize(*args)
  super
  @action = :install
end
