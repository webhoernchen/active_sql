class ActiveSqlOrganisation < ActiveRecord::Base
  has_many :employees, :class_name => 'ActiveSqlPerson'
  has_one :head, :class_name => "ActiveSqlPerson", :foreign_key => 'head_id'

  has_many :active_sql_notebooks_from_employees, :through => :employees, 
    :source => :active_sql_notebooks, :class_name => 'ActiveSqlNotebook'
  
  has_many :active_sql_sub_notebooks_from_employees, :through => :employees, 
    :source => :active_sql_sub_notebooks

  has_many :active_sql_notebooks_from_head, :through => :head, 
    :source => :active_sql_notebooks, :class_name => 'ActiveSqlNotebook'
  
  has_many :active_sql_sub_notebooks_from_head, :through => :head, 
    :source => :active_sql_sub_notebooks

  has_many :paid_active_sql_notebooks, :as => :paying_partner,
    :class_name => "ActiveSqlNotebook"
end
