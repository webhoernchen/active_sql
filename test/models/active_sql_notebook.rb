class ActiveSqlNotebook < ActiveRecord::Base
  has_one :active_sql_person
  belongs_to :paying_partner, :polymorphic => true
end
