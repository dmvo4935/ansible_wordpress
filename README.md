Ansible Roles for installation of Wordpress

testing the repo branching


#Installation (Ansible Part)

1. Install ansible to management node
  a. git clone https://github.com/evry/cloudascore-ansible.git
   the directory should look like below:

   cloudascore-ansible
├── ansible_windows
├── ati-0.4.4.dev0.tar.gz
├── ConfigureRemotingForAnsible.ps1
├── customer
├── install_ansible.yml
├── README.md
├── README.txt
├── terraform_inventory.sh
├── terraform.py
├── terraform.tfstate

  b. deploy ansible engine and imatis configuration to management node
     Run the command:
     `ansible-playbook -i ./terraform_inventory.sh -e "ansibe_password= mgmt_node=management-node"`

#Deployment

  1. Login to management_node
  2. Launch the deployment process:
     cd ~imatis_administrator/imatis
     ansible-playbook -i ../terraform_inventory.sh -e @imatis_vars.yml imatis.yml

#Parameters used by ansible in the deployment

Parameters used to for installation are defined in imatis_vars.yml file.
ad_safe_mode_password
ad_domain_name
ad_domain_password
ansible_password
cluster_name

#Description of ansible roles used for installation:

 ##primary_dc
 Creates primary domain controller. Within this role Powershell module xActiveDirectory is installed and xADDomain DSC resource is used to
 create the domain:

   `win_dsc:
     resource_name: xADDomain
     DomainName: '{{ad_domain_name}}'
     DomainAdministratorCredential_username: '{{ansible_user}}'
     DomainAdministratorCredential_password: '{{ansible_password}}'
     SafemodeAdministratorPassword_password: '{{ad_safe_mode_password}}'
     SafemodeAdministratorPassword_username: '{{ansible_user}}'`

  ##secondary_dc
  Creates secondary domain controller. Uses ip address of primary DC as input in order to find existing domain:

    `win_dsc:
      resource_name: xADDomainController
      DomainName: '{{ad_domain_name}}'
      DomainAdministratorCredential_username: '{{ansible_user}}@{{ad_domain_name}}'
      DomainAdministratorCredential_password: '{{ansible_password}}'
      SafemodeAdministratorPassword_password: '{{ad_safe_mode_password}}'
      SafemodeAdministratorPassword_username: '{{ansible_user}}'`

   Also creates windows share resource for later use by Microsoft Cluster Service as witness:
   `win_share:
    name: witness
    description: Witness for failover cluster
    path: C:\Shares\witness
    list: no
    full: Administrators`

    ##join_domain
    Performs the joining of all other hosts to AD Domain

    ##failover_cluster_node
    Installs xFailOverCluster powershell module and Failover-Clustering windows feature

    ##sql_server
    Performs installation of MS SQL Server using SqlServerDsc powershell win_psmodule
    `win_dsc:
      resource_name: SqlSetup
      Action: install
      InstanceName: MSSQLSERVER
      Features: 'SQLENGINE,AS'
      SourcePath: '\\imatis-sql-2\sql_install'
      ForceReboot: false
      InstallSharedDir: 'C:\Program Files\Microsoft SQL Server'
      InstallSharedWOWDir: 'C:\Program Files (x86)\Microsoft SQL Server'
      InstanceDir: 'C:\Program Files\Microsoft SQL Server'
      InstallSQLDataDir: 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
      SQLUserDBDir: 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
      SQLUserDBLogDir: 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
      SQLTempDBDir: 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
      SQLTempDBLogDir: 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data'
      SQLBackupDir: 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup'
      ASConfigDir: 'C:\MSOLAP\Config'
      ASDataDir: 'C:\MSOLAP\Data'
      ASLogDir: 'C:\MSOLAP\Log'
      ASBackupDir: 'C:\MSOLAP\Backup'
      ASTempDir: 'C:\MSOLAP\Temp'
      SQLCollation: 'SQL_Latin1_General_CP1_CI_AS'`

    ##always_on_prerequisites
    Performs number of tasks to prepare SQL server to join AlwaysOn availability group.
    Enables SQL AlwaysOn service on SQL nodes.
    Creates firewall rules for SQL server.
    Creates endpoint for SQL servers.
    Sets Permissions to ClusSvc and SYSTEM logins.
    Creates SQL login for ClusSvc Service

    ##iis_dsc
    Installs Web-Server Windows feature, creates IIS Website using xWebAdministration powershell module and xWebsite resource.

  #Description of separate tasks used within main playbook

    ##install_SSMS.yml
    Is used to install SQL Server management studio (optional). The installation is done from chokolatey repo.

    ##cluster_primary_node.yml
    Uses Installs Microsoft cluster services, creates High Availability cluster. Uses resources from xFailOverCluster module
    previously installed within the role "failover_cluster_node"
    `- win_dsc:
       resource_name: xCluster
       Name: '{{cluster_name}}'
       DomainAdministratorCredential_username: '{{ad_domain_name}}\{{ansible_user}}'
       DomainAdministratorCredential_password: '{{ansible_password}}'
       StaticIPAddress: 10.0.0.100/24
    - win_dsc:
       resource_name: xClusterQuorum
       resource: '\\ad-vm-2\witness'
       IsSingleInstance: 'Yes'
       Type: NodeAndFileShareMajority
       PsDscRunAsCredential_username: '{{ad_domain_name}}\{{ansible_user}}'
       PsDscRunAsCredential_password: '{{ansible_password}}'`

     ##cluster_update_dns.yml
     these tasks replace cluster ip address so that the node joining the cluster could contact the first node in the cluster
     directly.
     `win_dsc:
      resource_name: xDnsRecord
      Name: "{{cluster_name}}"
      Zone: '{{ad_domain_name}}'
      Target: 10.0.0.100
      DnsServer: '{{ansible_hostname}}'
      Type: ARecord
      Ensure: Absent
     win_dsc:
      resource_name: xDnsRecord
      Name: "{{cluster_name}}"
      Zone: '{{ad_domain_name}}'
      Target: "{{hostvars['SQL-VM1']['ansible_ip_addresses'][0]}}"
      DnsServer: '{{ansible_hostname}}'
      Type: ARecord
      Ensure: Present`

    ##cluster_secondary_node.yml
    Joins the node to Windows cluster using xFailOverCluster/xCluster resource

    ##sql_AG.yml
    Creates SQL AlwaysOn availability group on the first node in windows cluster. Requires SQL Instance is already up and running

    ##sql_AGReplica.yml
    Creates secondary replica in the Availability Group created by sql_AG.yml tasks
    `win_dsc:
      resource_name: SqlAGReplica
      Name: '{{ansible_hostname}}'
      AvailabilityGroupName: SQLAG1
      ServerName: '{{ansible_fqdn}}'
      InstanceName: MSSQLSERVER
      PrimaryReplicaServerName: imatis-sql-1.imatis.local
      PrimaryReplicaInstanceName: MSSQLSERVER
      AvailabilityMode: SynchronousCommit
      FailoverMode: Automatic`

      ##sql_create_db.yml
      Creates SQL database in the SQL instance

      ##sql_AGDB.yml
      Adds existing SQL database to AlwaysOn availability Group

      ##sql_AGListener.yml
      Creates the Listener in AlwaysOn Availability Group
