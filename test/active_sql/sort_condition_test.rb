require 'test_helper'
require File.join(File.dirname(__FILE__), '..', 'test_helper')

class ActiveSql::SortConditionTest < ActiveSupport::TestCase

  context "ActiveSqlPerson.generate_sort_condition without reflections" do
    context "without sort" do
      subject do 
        ActiveSqlPerson.generate_sort_condition do |organisation|
          organisation.first_name
        end
      end

      should 'return sort condition' do
        assert_equal "active_sql_people.first_name", subject
        assert_nothing_raised { ActiveSqlPerson.find(:all, :order => subject) }
      end
    end
    
    context "with sort" do 
      subject do 
        ActiveSqlPerson.generate_sort_condition do |person|
          person.first_name(:sort => 'ASC')
        end
      end

      should 'return sort condition with sort' do
        assert_equal "active_sql_people.first_name ASC", subject
        assert_nothing_raised { ActiveSqlPerson.find(:all, :order => subject) }
      end
    end
  end
  
  context "ActiveSqlPerson.by_active_sql_order_scope with belongs_to reflection" do
    setup do 
      organisation_datev = Factory :active_sql_organisation, :name => 'Datev'
      organisation_siemens = Factory :active_sql_organisation, :name => 'Siemens'

      @employee_by_datev = Factory :active_sql_person, :active_sql_organisation => organisation_datev
      @employee_by_siemens = Factory :active_sql_person, :active_sql_organisation => organisation_siemens
    end
    
    context "without sort" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |person|
          person.active_sql_organisation.name
        end
      end

      should_not_raise_an_error

      should 'return 2 Persons sorted by organisation name' do
        assert_equal [@employee_by_datev, @employee_by_siemens], subject
      end
    end
    
    context "with sort" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |person|
          person.active_sql_organisation.name(:sort => 'DESC')
        end
      end

      should_not_raise_an_error

      should 'return 2 Persons sorted by organisation name' do
        assert_equal [@employee_by_siemens, @employee_by_datev], subject
      end
    end
  end
  
  context "ActiveSqlNotebook.by_active_sql_order_scope with belongs_to polymorphic reflection" do
    setup do 
      eichhorn = Factory :active_sql_person, :last_name => 'Eichhorn'
      emrich = Factory :active_sql_person, :last_name => 'Emrich'

      @notebook_paid_by_eichhorn = Factory :active_sql_notebook, :paying_partner => eichhorn
      @notebook_paid_by_emrich = Factory :active_sql_notebook, :paying_partner => emrich
    end
    
    context "without sort" do 
      subject do 
        ActiveSqlNotebook.by_active_sql_order_scope do |notebook|
          notebook.paying_partner(:is => ActiveSqlPerson).last_name
        end
      end

      should_not_raise_an_error

      should 'return 2 notebooks sorted by last_name of paying_partner' do
        assert_equal [@notebook_paid_by_eichhorn, @notebook_paid_by_emrich], subject
      end
    end
    
    context "with sort" do 
      subject do 
        ActiveSqlNotebook.by_active_sql_order_scope do |notebook|
          notebook.paying_partner(:is => ActiveSqlPerson).last_name(:sort => 'DESC')
        end
      end

      should_not_raise_an_error

      should 'return 2 notebooks sorted by last_name of paying_partner' do
        assert_equal [@notebook_paid_by_emrich, @notebook_paid_by_eichhorn], subject
      end
    end
  end
  
  context "ActiveSqlOrganisation.by_active_sql_order_scope with has_one reflection" do
    setup do 
      eichhorn = Factory :active_sql_person, :last_name => 'Eichhorn'
      emrich = Factory :active_sql_person, :last_name => 'Emrich'

      @organisation_eichhorn = Factory :active_sql_organisation, :head => eichhorn
      @organisation_emrich = Factory :active_sql_organisation, :head => emrich
    end
    
    context "without sort" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organisation|
          organisation.head.last_name
        end
      end

      should_not_raise_an_error

      should 'return 2 organisations sorted by last_name of head' do
        assert_equal [@organisation_eichhorn, @organisation_emrich], subject
      end
    end
    
    context "with sort" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organisation|
          organisation.head.last_name(:sort => 'DESC')
        end
      end

      should_not_raise_an_error

      should 'return 2 organisations sorted by last_name of head' do
        assert_equal [@organisation_emrich, @organisation_eichhorn], subject
      end
    end
  end
  
  context "ActiveSqlPerson.by_active_sql_order_scope with has_and_belongs_to_many reflection" do
    setup do
      call_number_0910 = Factory :active_sql_call_number, :number => '091012345'
      call_number_0911 = Factory :active_sql_call_number, :number => '091112345'
      call_number_0912 = Factory :active_sql_call_number, :number => '091212345'
      call_number_0921 = Factory :active_sql_call_number, :number => '092112345'
      
      @person_with_call_number_0911 = Factory :active_sql_person, :active_sql_call_numbers => [call_number_0911]
      @person_with_call_number_0912 = Factory :active_sql_person, :active_sql_call_numbers => [call_number_0912]
      @person_with_call_number_0921_and_0910 = Factory :active_sql_person, :active_sql_call_numbers => [call_number_0921, call_number_0910]
    end
    
    context "without sort" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |organisation|
          organisation.active_sql_call_numbers.number
        end
      end

      should_not_raise_an_error

      should 'return 3 people sorted by call_number' do
        assert_equal [@person_with_call_number_0921_and_0910, @person_with_call_number_0911, @person_with_call_number_0912], subject
      end
    end
    
    context "with sort" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |organisation|
          organisation.active_sql_call_numbers.number :sort => 'DESC'
        end
      end

      should_not_raise_an_error

      should 'return 3 people sorted by call_number' do
        assert_equal [@person_with_call_number_0921_and_0910, @person_with_call_number_0912, @person_with_call_number_0911], subject
      end
    end
    
    context "with sort and limit" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |organisation|
          organisation.active_sql_call_numbers.number :sort => 'ASC', :limit => 2
        end
      end

      should_not_raise_an_error

      should 'return 3 people sorted by call_number' do
        assert_equal [@person_with_call_number_0921_and_0910, @person_with_call_number_0911, @person_with_call_number_0912], subject
      end
    end
    
    context "with sort 'ASC' and inner_sort 'DESC'" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |organisation|
          organisation.active_sql_call_numbers.number :inner_sort => 'DESC', :sort => 'ASC'
        end
      end

      should_not_raise_an_error

      should 'return 3 people sorted by call_number' do
        assert_equal [@person_with_call_number_0911, @person_with_call_number_0912, @person_with_call_number_0921_and_0910], subject
      end
    end
  end
  
  context "ActiveSqlOrganisation.by_active_sql_order_scope with has_many reflection" do
    setup do
      employee_eichhorn = Factory :active_sql_person, :last_name => 'Eichhorn'
      employee_emrich = Factory :active_sql_person, :last_name => 'Emrich'
    
      @organisation_with_employee_eichhorn = Factory :active_sql_organisation, :employees => [employee_eichhorn]
      @organisation_with_employee_emrich = Factory :active_sql_organisation, :employees => [employee_emrich]
    end

    context "without sort" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organisation|
          organisation.employees.last_name
        end
      end

      should_not_raise_an_error

      should "return 2 organisations sorted by employees last_name" do 
        assert_equal [@organisation_with_employee_eichhorn, @organisation_with_employee_emrich], subject
      end
    end

    context "with sort" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organisation|
          organisation.employees.last_name :sort => 'DESC'
        end
      end

      should_not_raise_an_error

      should "return 2 organisations sorted by employees last_name" do 
        assert_equal [@organisation_with_employee_emrich, @organisation_with_employee_eichhorn], subject
      end
    end
  end
  
  context "ActiveSqlPerson.by_active_sql_order_scope with has_many through belongs_to reflection" do
    setup do
      organisation_1 = Factory :active_sql_organisation
      organisation_2 = Factory :active_sql_organisation
      
      @eichhorn = Factory :active_sql_person, :last_name => 'Eichhorn', :active_sql_organisation => organisation_1
      @emrich = Factory :active_sql_person, :last_name => 'Emrich', :active_sql_organisation => organisation_2
      @schad = Factory :active_sql_person, :last_name => 'Schad', :active_sql_organisation => organisation_1
    end

    context "without sort" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |person|
          person.colleagues.last_name
        end
      end

      should_not_raise_an_error

      should "return 3 people sorted by colleagues last_name" do 
        assert_equal [@emrich, @schad, @eichhorn], subject
      end
    end

    context "with sort" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |person|
          person.colleagues.last_name :sort => 'DESC'
        end
      end

      should_not_raise_an_error

      should "return 3 people sorted by colleagues last_name" do 
        assert_equal [@eichhorn, @schad, @emrich], subject
      end
    end
  end
  
  context "ActiveSqlOrganisation.by_active_sql_order_scope with has_many through has_many reflection" do
    setup do
      notebook_with_number_12345 = Factory :active_sql_notebook, :number => '12345'
      @organisation_with_employee_with_notebook_number_12345 = Factory :active_sql_organisation
      employee_with_notebook_number_12345 = Factory :active_sql_person, 
        :active_sql_notebook => notebook_with_number_12345, 
        :active_sql_organisation => @organisation_with_employee_with_notebook_number_12345
      
      notebook_with_number_54321 = Factory :active_sql_notebook, :number => '54321'
      @organisation_with_employee_with_notebook_number_54321 = Factory :active_sql_organisation
      employee_with_notebook_number_54321 = Factory :active_sql_person, 
        :active_sql_notebook => notebook_with_number_54321, 
        :active_sql_organisation => @organisation_with_employee_with_notebook_number_54321
    end

    context "without sort" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organization|
          organization.active_sql_notebooks_from_employees.number
        end
      end

      should_not_raise_an_error

      should "return 2 organisations ordered by the notebook number" do 
        expected =  [@organisation_with_employee_with_notebook_number_12345, 
          @organisation_with_employee_with_notebook_number_54321]
        assert_equal expected, subject
      end
    end

    context "with sort" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organization|
          organization.active_sql_notebooks_from_employees.number :sort => 'DESC'
        end
      end

      should_not_raise_an_error

      should "return 2 organisations ordered by the notebook number" do 
        expected =  [@organisation_with_employee_with_notebook_number_54321, 
          @organisation_with_employee_with_notebook_number_12345]
        assert_equal expected, subject
      end
    end
  end
  
  context "ActiveSqlPerson.by_active_sql_order_scope with has_many through polymorphic reflection" do
    setup do
      @employee_with_notebook_number_12345 = Factory :active_sql_person
      notebook_with_number_12345 = Factory :active_sql_notebook, :number => '12345', 
        :paying_partner => @employee_with_notebook_number_12345
      
      @employee_with_notebook_number_54321 = Factory :active_sql_person
      notebook_with_number_54321 = Factory :active_sql_notebook, :number => '54321',
        :paying_partner => @employee_with_notebook_number_54321
    end

    context "without sort" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |person|
          person.paid_active_sql_notebooks.number
        end
      end

      should_not_raise_an_error

      should "return 2 people ordered by the notebook number" do 
        expected =  [@employee_with_notebook_number_12345, 
          @employee_with_notebook_number_54321]
        assert_equal expected, subject
      end
    end

    context "with sort" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |person|
          person.paid_active_sql_notebooks.number :sort => 'DESC'
        end
      end

      should_not_raise_an_error

      should "return 2 people ordered by the notebook number" do 
        expected =  [@employee_with_notebook_number_54321, 
          @employee_with_notebook_number_12345]
        assert_equal expected, subject
      end
    end
  end
  
  context "ActiveSqlPerson.by_active_sql_order_scope with has_one and belongs_to parent reflection" do
    setup do
      organisation_1 = Factory :active_sql_organisation
      head_1 = Factory :active_sql_person, :first_name => 'Christian', 
        :active_sql_organisation_as_head => organisation_1
      @employee_with_head_christian = Factory :active_sql_person, 
        :active_sql_organisation => organisation_1
      
      organisation_2 = Factory :active_sql_organisation
      head_2 = Factory :active_sql_person, :first_name => 'Martina', 
        :active_sql_organisation_as_head => organisation_2
      @employee_with_head_martina = Factory :active_sql_person, 
        :active_sql_organisation => organisation_2
    end
    
    context "without sort" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |person|
          person.active_sql_organisation.head.first_name
        end.by_active_sql_condition_scope do |person|
          person.active_sql_organisation_id.is_not_blank
        end
      end

      should_not_raise_an_error

      should 'return 2 Persons sorted by first_name of the head' do
        assert_equal [@employee_with_head_christian, @employee_with_head_martina], subject
      end
    end
    
    context "with sort" do 
      subject do 
        ActiveSqlPerson.by_active_sql_order_scope do |person|
          person.active_sql_organisation.head.first_name(:sort => 'DESC')
        end.by_active_sql_condition_scope do |person|
          person.active_sql_organisation_id.is_not_blank
        end
      end

      should_not_raise_an_error

      should 'return 2 Persons sorted by first_name of the head' do
        assert_equal [@employee_with_head_martina, @employee_with_head_christian], subject
      end
    end
  end
  
  context "ActiveSqlNotebook.by_active_sql_order_scope with belongs_to and belongs_to parent reflection" do
    setup do
      organisation_siemens = Factory :active_sql_organisation, :name => 'Siemens'
      employee_by_siemens = Factory :active_sql_person, 
        :active_sql_organisation => organisation_siemens
      @notebook_of_siemens = Factory :active_sql_notebook, 
        :active_sql_person => employee_by_siemens
      
      organisation_datev = Factory :active_sql_organisation, :name => 'Datev'
      employee_by_datev = Factory :active_sql_person, 
        :active_sql_organisation => organisation_datev
      @notebook_of_datev = Factory :active_sql_notebook, 
        :active_sql_person => employee_by_datev
    end
    
    context "without sort" do 
      subject do 
        ActiveSqlNotebook.by_active_sql_order_scope do |notebook|
          notebook.active_sql_person.active_sql_organisation.name
        end
      end

      should_not_raise_an_error

      should 'return 2 Notebooks sorted by name of the organisation of the person' do
        assert_equal [@notebook_of_datev, @notebook_of_siemens], subject
      end
    end
    
    context "with sort" do 
      subject do 
        ActiveSqlNotebook.by_active_sql_order_scope do |notebook|
          notebook.active_sql_person.active_sql_organisation.name(:sort => 'DESC')
        end
      end

      should_not_raise_an_error

      should 'return 2 Notebooks sorted by name of the organisation of the person' do
        assert_equal [@notebook_of_siemens, @notebook_of_datev], subject
      end
    end
  end
  
  context "ActiveSqlOrganisation.by_active_sql_order_scope with has_many and has_and_belongs_to_many parent reflection" do
    setup do
      @organisation_with_callnumber_123456 = Factory :active_sql_organisation
      employee_by_organisation_with_call_number_123456 = Factory :active_sql_person, 
        :active_sql_organisation => @organisation_with_callnumber_123456
      call_number_1 = Factory :active_sql_call_number, :number => '1234567',
        :active_sql_people => [employee_by_organisation_with_call_number_123456]
      
      @organisation_with_callnumber_654321 = Factory :active_sql_organisation
      employee_by_organisation_with_call_number_654321 = Factory :active_sql_person, 
        :active_sql_organisation => @organisation_with_callnumber_654321
      call_number_2 = Factory :active_sql_call_number, :number => '6543217',
        :active_sql_people => [employee_by_organisation_with_call_number_654321]
    end
    
    context "without sort" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organisation|
          organisation.employees.active_sql_call_numbers.number
        end
      end

      should_not_raise_an_error

      should 'return 2 Oragnisations sorted by call_number of the employees' do
        assert_equal [@organisation_with_callnumber_123456, 
          @organisation_with_callnumber_654321], subject
      end
    end
    
    context "with sort" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organisation|
          organisation.employees.active_sql_call_numbers.number(:sort => 'DESC')
        end
      end

      should_not_raise_an_error

      should 'return 2 Oragnisations sorted by call_number of the employees' do
        assert_equal [@organisation_with_callnumber_654321, 
          @organisation_with_callnumber_123456], subject
      end
    end
  end
  
  context "ActiveSqlOrganisation.by_active_sql_order_scope with has_many and has_many parent reflection" do
    setup do
      @organisation_1 = Factory :active_sql_organisation
      employee_by_organisation_1 = Factory :active_sql_person, 
        :active_sql_organisation => @organisation_1
      notebook_1 = Factory :active_sql_notebook, :number => '1234567',
        :paying_partner => employee_by_organisation_1
      
      @organisation_2 = Factory :active_sql_organisation
      employee_by_organisation_2 = Factory :active_sql_person, 
        :active_sql_organisation => @organisation_2
      notebook_2 = Factory :active_sql_notebook, :number => '7654321',
        :paying_partner => employee_by_organisation_2
    end
    
    context "without sort" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organisation|
          organisation.employees.paid_active_sql_notebooks.number
        end
      end

      should_not_raise_an_error

      should 'return 2 Oragnisations notebooks of the employees' do
        assert_equal [@organisation_1, @organisation_2], subject
      end
    end
    
    context "with sort" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organisation|
          organisation.employees.paid_active_sql_notebooks.number(:sort => 'DESC')
        end
      end

      should_not_raise_an_error

      should 'return 2 Oragnisations notebooks of the employees' do
        assert_equal [@organisation_2, @organisation_1], subject
      end
    end
  end
  
  context "ActiveSqlOrganisation.by_active_sql_order_scope" do
    setup do
      @organisation_1 = Factory :active_sql_organisation
      employee_by_organisation_1 = Factory :active_sql_person, 
        :active_sql_organisation => @organisation_1
      notebook_1 = Factory :active_sql_notebook, :number => '1234567',
        :paying_partner => employee_by_organisation_1
      
      @organisation_2 = Factory :active_sql_organisation
      employee_by_organisation_2 = Factory :active_sql_person, 
        :active_sql_organisation => @organisation_2
      notebook_2 = Factory :active_sql_notebook, :number => '7654321',
        :paying_partner => employee_by_organisation_2
    end

    context "with sort and condition" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organisation|
          organisation.employees.paid_active_sql_notebooks.condition do |cond|
            cond.name.includes('76')
          end.number(:sort => 'DESC')
        end
      end

      should_not_raise_an_error

      should 'return 2 Oragnisations notebooks of the employees' do
        assert_equal [@organisation_1, @organisation_2], subject
      end
    end
  end
end
