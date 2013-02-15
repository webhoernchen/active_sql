FactoryGirl.define  do 
  factory :active_sql_organisation, :class => "ActiveSqlOrganisation" do |org|
    org.sequence(:name) {|n| "Organisation #{n}" }
  end

  factory :active_sql_person, :class => "ActiveSqlPerson" do |person|
    person.sequence(:first_name) {|n| "First name #{n}" }
    person.sequence(:last_name) {|n| "Last name #{n}" }
  end

  factory :active_sql_call_number, :class => "ActiveSqlCallNumber" do |f|
    f.number_type 'phone'
    f.number '123456'
  end

  factory :active_sql_notebook, :class => "ActiveSqlNotebook" do |f|
    f.number '123456'
    f.name 'HP XP-DESC'
    f.description 'bla bla blabla'
  end
end
