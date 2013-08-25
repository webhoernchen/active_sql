class ActiveSqlPerson < ActiveRecord::Base
  belongs_to :active_sql_organisation
  has_and_belongs_to_many :active_sql_call_numbers,
    :join_table => 'active_sql_call_numbers_active_sql_people'
  belongs_to :active_sql_notebook
  belongs_to :active_sql_sub_notebook
  belongs_to :active_sql_organisation_as_head, :foreign_key => 'head_id', 
    :class_name => 'ActiveSqlOrganisation'

  if Rails.version >= '4.0.0'
  has_many :colleagues, :through => :active_sql_organisation, :source => :employees,
    :conditions => lambda { where('active_sql_people.id != #{id}') }
  else
  has_many :colleagues, :through => :active_sql_organisation, :source => :employees,
    :conditions => 'active_sql_people.id != #{id}'
  end

  has_many :paid_active_sql_notebooks, :as => :paying_partner,
    :class_name => "ActiveSqlNotebook"
end
