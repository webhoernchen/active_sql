module TestTables

  def create_tables
    drop_old_table_definition
    create_tables_with_new_definition
  end

  private
  def drop_old_table_definition
    connection = ActiveRecord::Base.connection
    connection.tables.grep(/active_sql_[a-z_]*/).each do |table|
      connection.drop_table(table)
    end
  end

  def create_tables_with_new_definition
    create_table_people
    create_table_organisations
    create_table_call_numbers
    create_table_notebooks
  end

  def create_table_people
    create_table :active_sql_people do |t|
      t.string :first_name, :last_name
      t.date :birthday
      t.integer :active_sql_organisation_id, :head_id, :active_sql_notebook_id, :active_sql_sub_notebook_id
    end
  end

  def create_table_organisations
    create_table :active_sql_organisations do |t|
      t.string :name
    end
  end

  def create_table_call_numbers
    create_table :active_sql_call_numbers do |t|
      t.string :number_type, :number
    end

    create_table :active_sql_call_numbers_active_sql_people, :id => false do |t|
      t.integer :active_sql_call_number_id, :active_sql_person_id
    end
  end

  def create_table_notebooks
    create_table :active_sql_notebooks do |t|
      t.string :number, :name, :type, :paying_partner_type
      t.text :description
      t.integer :paying_partner_id, :active_sql_notebook_id
    end
  end

  def create_table(name, options={}, &block)
    ActiveRecord::Schema.define do
      create_table name, options do |t|
        yield(t)
      end
    end
  end
end
