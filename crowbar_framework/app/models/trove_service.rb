#
# Copyright 2013-2014, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
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
#

class TroveService < ServiceObject

  def initialize(thelogger)
    super(thelogger)
    @bc_name = "trove"
  end

  def create_proposal
    @logger.debug("Trove create_proposal: entering")
    base = super

    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")
    base["attributes"][@bc_name]["nova_instance"] = find_dep_proposal("nova")
    base["attributes"][@bc_name]["cinder_instance"] = find_dep_proposal("cinder")
    base["attributes"][@bc_name]["swift_instance"] = find_dep_proposal("swift")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")

    @logger.debug("Trove create_proposal: exiting")
    base
  end

  def self.allow_multiple_proposals?
    false
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes[@bc_name]["keystone_instance"] }
    answer << { "barclamp" => "nova", "inst" => role.default_attributes[@bc_name]["nova_instance"] }
    answer << { "barclamp" => "cinder", "inst" => role.default_attributes[@bc_name]["cinder_instance"] }
    answer << { "barclamp" => "swift", "inst" => role.default_attributes[@bc_name]["swift_instance"] }
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes[@bc_name]["rabbitmq_instance"] }
    answer
  end
end

