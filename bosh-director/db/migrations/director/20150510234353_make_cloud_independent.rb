Sequel.migration do
  change do
    alter_table(:clouds) do
      drop_column :deployment_id
    end
  end
end
