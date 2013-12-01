class AddOmniAuthToUsers < ActiveRecord::Migration
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :name, :string

    add_index :users, [:provider, :uid], unique: true
  end
end
