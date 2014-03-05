
env_filter = " AND rabbitmq_config_environment:rabbitmq-config-#{node[:ceilometer][:rabbitmq_instance]}"
rabbits = search(:node, "roles:rabbitmq-server#{env_filter}") || []
if rabbits.length > 0
  rabbit = rabbits[0]
  rabbit = node if rabbit.name == node.name
else
  rabbit = node
end
rabbit_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(rabbit, "admin").address
Chef::Log.info("Rabbit server found at #{rabbit_address}")
rabbit_settings = {
  :address => rabbit_address,
  :port => rabbit[:rabbitmq][:port],
  :user => rabbit[:rabbitmq][:user],
  :password => rabbit[:rabbitmq][:password],
  :vhost => rabbit[:rabbitmq][:vhost]
}

keystone_settings = CeilometerHelper.keystone_settings(node)

if node[:ceilometer][:use_mongodb]
  db_hosts = search(:node, "roles:ceilometer-server") || []
  if db_hosts.length > 0
    db_host = db_hosts.first
    db_host = node if db_host.name == node.name
  else
    db_host = node
  end
  mongodb_ip=Chef::Recipe::Barclamp::Inventory.get_network_by_type(db_host, "admin").address
  db_connection = "mongodb://#{mongodb_ip}:27017/ceilometer"
else
  sql_env_filter = " AND database_config_environment:database-config-#{node[:ceilometer][:database_instance]}"
  sqls = search(:node, "roles:database-server#{sql_env_filter}")
  if sqls.length > 0
    sql = sqls[0]
    sql = node if sql.name == node.name
  else
    sql = node
  end

  sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil?
  Chef::Log.info("SQL server found at #{sql_address}")

  include_recipe "database::client"
  backend_name = Chef::Recipe::Database::Util.get_backend_name(sql)
  include_recipe "#{backend_name}::client"
  include_recipe "#{backend_name}::python-client"

  db_password = ''
  if node.roles.include? "ceilometer-server"
    # password is already created because common recipe comes
    # after the server recipe
    db_password = node[:ceilometer][:db][:password]
  else
    # pickup password to database from ceilometer-server node
    node_controllers = search(:node, "roles:ceilometer-server") || []
    if node_controllers.length > 0
      db_password = node_controllers[0][:ceilometer][:db][:password]
    end
  end

  db_connection = "#{backend_name}://#{node[:ceilometer][:db][:user]}:#{db_password}@#{sql_address}/#{node[:ceilometer][:db][:database]}"
end

if node[:ceilometer][:ha][:server][:enabled]
  admin_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
  bind_host = admin_address
  bind_port = node[:ceilometer][:ha][:ports][:api]
else
  bind_host = "0.0.0.0"
  bind_port = node[:ceilometer][:api][:port]
end

template "/etc/ceilometer/ceilometer.conf" do
    source "ceilometer.conf.erb"
    owner node[:ceilometer][:user]
    group node[:ceilometer][:group]
    mode "0640"
    variables(
      :debug => node[:ceilometer][:debug],
      :verbose => node[:ceilometer][:verbose],
      :rabbit_settings => rabbit_settings,
      :keystone_settings => keystone_settings,
      :bind_host => bind_host,
      :bind_port => bind_port,
      :metering_secret => node[:ceilometer][:metering_secret],
      :database_connection => db_connection,
      :node_hostname => node['hostname']
    )
end

template "/etc/ceilometer/pipeline.yaml" do
  source "pipeline.yaml.erb"
  owner node[:ceilometer][:user]
  group node[:ceilometer][:group]
  mode "0640"
  variables({
      :meters_interval => node[:ceilometer][:meters_interval],
      :cpu_interval => node[:ceilometer][:cpu_interval]
  })
end
