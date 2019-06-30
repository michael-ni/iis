#
# Author:: Jason Field
# Cookbook:: iis
# Resource:: manager
#
# Copyright:: 2018, Calastone Ltd.
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
# Configures IIS Manager

property :enable_remote_management, [TrueClass, FalseClass], default: true
property :log_directory, String
property :port, Integer, default: 8172

action :config do
  iis_install 'Web-Mgmt-Service' do
    additional_components ['IIS-ManagementService']
  end

  # properties stored in the registry
  reg_values = [{
    name: 'EnableRemoteManagement',
    type: :dword,
    data: new_resource.enable_remote_management ? 1 : 0,
  }, {
    name: 'Port',
    type: :dword,
    data: new_resource.port,
  }]

  if property_is_set?(:log_directory)
    directory new_resource.log_directory do
      recursive true
    end

    reg_values.push(
      name: 'LoggingDirectory',
      type: :string,
      data: new_resource.log_directory
    )
  end

  registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WebManagement\Server' do
    values    reg_values
    notifies  :restart, 'service[WMSVC]', :delayed
  end

  # if using a custom port then we need to allow the service account to listen on it
  if property_is_set?(:port)
    windows_http_acl "https://*:#{new_resource.port}/" do
      user 'NT SERVICE\WMSvc'
    end
    # WMSVC is the self signed cert auto generated by windows
    windows_certificate_binding 'WMSVC' do
      port    new_resource.port
      app_id  '{d7d72267-fcf9-4424-9eec-7e1d8dcec9a9}'
    end
  end

  service 'WMSVC' do
    action [:enable, :start]
  end
end
