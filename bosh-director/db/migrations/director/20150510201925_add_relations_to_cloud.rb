Sequel.migration do
  change do
    alter_table(:cloud_configs) do
      add_column :cloud_id, Integer
    end

    alter_table(:deployments) do
      add_column :cloud_id, Integer
    end

    alter_table(:stemcells) do
      add_column :cloud_id, Integer
    end

    create_table :deployments_clouds do
      primary_key :id
      foreign_key :deployment_id, :deployments, :null => false
      foreign_key :stemcell_id, :stemcells, :null => false
      unique [:deployment_id, :stemcell_id]
    end


  end
end
