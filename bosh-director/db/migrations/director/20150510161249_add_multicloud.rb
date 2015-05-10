# has_one deployment
# has_one cloud_config
# has_many stemcells
# has_many jobs
# has_many persistent_disks

Sequel.migration do
  up do
    create_table(:clouds) do
      primary_key :id
      foreign_key :cloud_config_id, :cloud_configs, :null => false
      foreign_key :deployment_id, :deployments, :null => false

      text :name
      text :type
      text :endpoint

      Time :created_at, null: false
      index :created_at
    end
  end

  down do
    drop_table(:clouds)
  end

end
