class ActiveSqlCallNumber < ActiveRecord::Base
  has_and_belongs_to_many :active_sql_people
end