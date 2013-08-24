require 'test_helper'
require File.join(File.dirname(__FILE__), '..', 'test_helper')

class ActiveSql::FinderTest < ActiveSupport::TestCase
  class SpecialPerson < ActiveSqlPerson
    active_sql_condition_scope :with_number do |person, number|
      person.active_sql_call_numbers.number.include number
    end

    active_sql_order_scope :sort_by_call_number do |person|
      person.active_sql_call_numbers.number(:limit => 3, :sort => 'ASC')
      #person.first_name(:sort => 'DESC')
    end
  end

  context "SpecialPerson" do 
    should "has scope :with_number" do 
      assert SpecialPerson.respond_to?(:with_number)
    end

    context "with call_number" do 
      setup do 
        @call_number = FactoryGirl.create(:active_sql_call_number, :number => "123456")
        @person = SpecialPerson.find(FactoryGirl.create(:active_sql_person).id)
        @person.active_sql_call_numbers << @call_number
      end

      should "be find with SpecialPerson.with_number '34'" do 
        assert SpecialPerson.with_number("34").include?(@person)
      end
    end
    
    context "Given 2 Persons with different call_numbers" do 
      setup do 
        @call_number_1 = FactoryGirl.create(:active_sql_call_number, :number => "123456")
        @call_number_2 = FactoryGirl.create(:active_sql_call_number, :number => "567890")
        @person_1 = SpecialPerson.find(FactoryGirl.create(:active_sql_person).id)
        @person_2 = SpecialPerson.find(FactoryGirl.create(:active_sql_person).id)
        @person_1.active_sql_call_numbers << @call_number_1
        @person_2.active_sql_call_numbers << @call_number_2
      end

      context "SpecialPerson.with_number('34').all" do 
        setup do 
          @persons = SpecialPerson.with_number('34').to_a
        end

        should "find @person_1" do 
          assert @persons.include?(@person_1)
        end

        should "not find @person_2" do 
          assert !@persons.include?(@person_2)
        end
      end
      
      context "SpecialPerson.by_active_sql_condition_scope" do 
        setup do 
          person_scope = SpecialPerson.by_active_sql_condition_scope do |person|
            person.active_sql_call_numbers.number.include('34')
          end
          @persons = person_scope.to_a
        end

        should "find @person_1" do 
          assert @persons.include?(@person_1)
        end

        should "not find @person_2" do 
          assert !@persons.include?(@person_2)
        end
      end

      context "SpecialPerson.sort_by_call_number" do 
        setup do 
          @persons = SpecialPerson.sort_by_call_number.to_a
        end

        should "find 2 persons" do 
          assert_equal 2, @persons.size
        end
      end
    end
  end

  context "ActiveSqlOrganisation.by_active_sql_order_scope by name and name of the head" do 
    setup do 
      @organisation_siemens = FactoryGirl.create :active_sql_organisation, :name => 'Siemens'
      head_of_siemens = FactoryGirl.create :active_sql_person, :last_name => 'Siemens',
        :active_sql_organisation_as_head => @organisation_siemens
      @organisation_siemens_2 = FactoryGirl.create :active_sql_organisation, :name => 'Siemens'
      head_of_siemens_2 = FactoryGirl.create :active_sql_person, :last_name => 'Schuckert',
        :active_sql_organisation_as_head => @organisation_siemens_2
      
      @organisation_other = FactoryGirl.create :active_sql_organisation, :name => 'Other'
      head_of_other = FactoryGirl.create :active_sql_person, :last_name => 'mustermann',
        :active_sql_organisation_as_head => @organisation_other
    end

    context "" do 
      subject do 
        ActiveSqlOrganisation.by_active_sql_order_scope do |organisation|
          cond = [organisation.name]
          cond << organisation.head.last_name
          cond
        end
      end

      should_not_raise_an_error

      should "return the 3 organisations sorted" do
        assert_equal [@organisation_other, @organisation_siemens_2, @organisation_siemens], subject
      end
    end
  end
end
