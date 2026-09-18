class CreateUuidPrincipals < ActiveRecord::Migration[8.0]
  def change
    create_table :uuid_principals, id: :uuid
  end
end
