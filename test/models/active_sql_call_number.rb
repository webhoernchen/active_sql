class ActiveSqlCallNumber < ActiveRecord::Base
  has_and_belongs_to_many :active_sql_people,
    :join_table => 'active_sql_call_numbers_active_sql_people' # for Rails 4
end
