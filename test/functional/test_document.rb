require 'test_helper'
require 'models'

class DocumentTest < Test::Unit::TestCase
  def setup
    @document = Class.new do
      include MongoMapper::Document
      collection 'users'

      key :first_name, String
      key :last_name, String
      key :age, Integer
    end
    
    @document.collection.clear
  end
  
  context "Document Class Methods" do
    context "Using key with type Array" do
      setup do
        @document.key :tags, Array
      end
      
      should "work" do
        doc = @document.new
        doc.tags.should == []
        doc.tags = %w(foo bar)
        doc.save
        doc.tags.should == %w(foo bar)
        @document.find(doc.id).tags.should == %w(foo bar)
      end
    end
  
    context "Using key with type Hash" do
      setup do
        @document.key :foo, Hash
      end
  
      should "work with indifferent access" do
        doc = @document.new
        doc.foo = {:baz => 'bar'}
        doc.save
  
        doc = @document.find(doc.id)
        doc.foo[:baz].should == 'bar'
        doc.foo['baz'].should == 'bar'
      end
    end
  
    context "Saving a document with an embedded document" do
      setup do
        @document.class_eval do
          key :foo, Address
        end
      end
  
      should "embed embedded document" do
        address = Address.new(:city => 'South Bend', :state => 'IN')
        doc = @document.new(:foo => address)
        doc.save
        doc.foo.city.should == 'South Bend'
        doc.foo.state.should == 'IN'
  
        from_db = @document.find(doc.id)
        from_db.foo.city.should == 'South Bend'
        from_db.foo.state.should == 'IN'
      end
    end
  
    context "Creating a single document" do
      setup do
        @doc_instance = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
      end
  
      should "create a document in correct collection" do
        @document.count.should == 1
      end
  
      should "automatically set id" do
        @doc_instance.id.should_not be_nil
        @doc_instance.id.size.should == 24
      end
  
      should "return instance of document" do
        @doc_instance.should be_instance_of(@document)
        @doc_instance.first_name.should == 'John'
        @doc_instance.last_name.should == 'Nunemaker'
        @doc_instance.age.should == 27
      end
    end
    
    context "Creating a document with no attributes provided" do
      setup do
        @document = Class.new do
          include MongoMapper::Document
        end
        @document.collection.clear
      end
      
      should "create the document" do
        lambda {
          @document.create
        }.should change { @document.count }.by(1)
      end
    end
    
    context "Creating multiple documents" do
      setup do
        @doc_instances = @document.create([
          {:first_name => 'John', :last_name => 'Nunemaker', :age => '27'},
          {:first_name => 'Steve', :last_name => 'Smith', :age => '28'},
        ])
      end
  
      should "create multiple documents" do
        @document.count.should == 2
      end
  
      should "return an array of doc instances" do
        @doc_instances.map do |doc_instance|
          doc_instance.should be_instance_of(@document)
        end
      end
    end
  
    context "Updating a document" do
      setup do
        doc = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc_instance = @document.update(doc.id, {:age => 40})
      end
  
      should "update attributes provided" do
        @doc_instance.age.should == 40
      end
  
      should "not update existing attributes that were not set to update" do
        @doc_instance.first_name.should == 'John'
        @doc_instance.last_name.should == 'Nunemaker'
      end
  
      should "not create new document" do
        @document.count.should == 1
      end
    end
  
    should "raise error when updating single doc if not provided id and attributes" do
      doc = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
      lambda { @document.update }.should raise_error(ArgumentError)
      lambda { @document.update(doc.id) }.should raise_error(ArgumentError)
      lambda { @document.update(doc.id, [1]) }.should raise_error(ArgumentError)
    end
  
    context "Updating multiple documents" do
      setup do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
  
        @doc_instances = @document.update({
          @doc1.id => {:age => 30},
          @doc2.id => {:age => 30},
        })
      end
  
      should "not create any new documents" do
        @document.count.should == 2
      end
  
      should "should return an array of doc instances" do
        @doc_instances.map do |doc_instance|
          doc_instance.should be_instance_of(@document)
        end
      end
  
      should "update the documents" do
        @document.find(@doc1.id).age.should == 30
        @document.find(@doc2.id).age.should == 30
      end
    end
  
    should "raise error when updating multiple documents if not a hash" do
      lambda { @document.update([1, 2]) }.should raise_error(ArgumentError)
    end
  
    context "Finding documents" do
      setup do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
        @doc3 = @document.create({:first_name => 'Steph', :last_name => 'Nunemaker', :age => '26'})
      end
  
      should "raise document not found if nothing provided" do
        lambda { @document.find }.should raise_error(MongoMapper::DocumentNotFound)
      end
  
      context "with a single id" do
        should "work" do
          @document.find(@doc1.id).should == @doc1
        end
  
        should "raise error if document not found" do
          lambda { @document.find(MongoID.new) }.should raise_error(MongoMapper::DocumentNotFound)
        end
        
        should "raise error if id is illegal" do
          lambda { @document.find(1) }.should raise_error(MongoMapper::IllegalID)
        end
      end
      
      context "with multiple id's" do
        should "work as arguments" do
          @document.find(@doc1.id, @doc2.id).should == [@doc1, @doc2]
        end
  
        should "work as array" do
          @document.find([@doc1.id, @doc2.id]).should == [@doc1, @doc2]
        end
      end
  
      context "with :all" do
        should "find all documents" do
          @document.find(:all, :order => 'first_name').should == [@doc1, @doc3, @doc2]
        end
  
        should "be able to add conditions" do
          @document.find(:all, :conditions => {:first_name => 'John'}).should == [@doc1]
        end
      end
  
      context "with #all" do
        should "find all documents based on criteria" do
          @document.all(:order => 'first_name').should == [@doc1, @doc3, @doc2]
          @document.all(:conditions => {:last_name => 'Nunemaker'}).should == [@doc1, @doc3]
        end
      end
  
      context "with :first" do
        should "find first document" do
          @document.find(:first, :order => 'first_name').should == @doc1
        end
      end
  
      context "with #first" do
        should "find first document based on criteria" do
          @document.first(:order => 'first_name').should == @doc1
          @document.first(:conditions => {:age => 28}).should == @doc2
        end
      end
  
      context "with :last" do
        should "find last document" do
          @document.find(:last).should == @doc3
        end
      end
  
      context "with #last" do
        should "find last document based on criteria" do
          @document.last.should == @doc3
          @document.last(:conditions => {:age => 28}).should == @doc2
        end
      end
    end # finding documents
  
    context "Finding document by id" do
      setup do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
      end
  
      should "be able to find by id" do
        @document.find_by_id(@doc1.id).should == @doc1
        @document.find_by_id(@doc2.id).should == @doc2
      end
  
      should "return nil if document not found" do
        @document.find_by_id(MongoID.new).should be(nil)
      end
    end
  
    context "Deleting a document" do
      setup do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
        @document.delete(@doc1.id)
      end
  
      should "remove document from collection" do
        @document.count.should == 1
      end
  
      should "not remove other documents" do
        @document.find(@doc2.id).should_not be(nil)
      end
    end
  
    context "Deleting multiple documents" do
      should "work with multiple arguments" do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
        @doc3 = @document.create({:first_name => 'Steph', :last_name => 'Nunemaker', :age => '26'})
        @document.delete(@doc1.id, @doc2.id)
  
        @document.count.should == 1
      end
  
      should "work with array as argument" do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
        @doc3 = @document.create({:first_name => 'Steph', :last_name => 'Nunemaker', :age => '26'})
        @document.delete([@doc1.id, @doc2.id])
  
        @document.count.should == 1
      end
    end
  
    context "Deleting all documents" do
      setup do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
        @doc3 = @document.create({:first_name => 'Steph', :last_name => 'Nunemaker', :age => '26'})
      end
  
      should "remove all documents when given no conditions" do
        @document.delete_all
        @document.count.should == 0
      end
  
      should "only remove matching documents when given conditions" do
        @document.delete_all({:first_name => 'John'})
        @document.count.should == 2
      end
  
      should "convert the conditions to mongo criteria" do
        @document.delete_all(:age => [26, 27])
        @document.count.should == 1
      end
    end
  
    context "Destroying a document" do
      setup do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
        @document.destroy(@doc1.id)
      end
  
      should "remove document from collection" do
        @document.count.should == 1
      end
  
      should "not remove other documents" do
        @document.find(@doc2.id).should_not be(nil)
      end
    end
  
    context "Destroying multiple documents" do
      should "work with multiple arguments" do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
        @doc3 = @document.create({:first_name => 'Steph', :last_name => 'Nunemaker', :age => '26'})
        @document.destroy(@doc1.id, @doc2.id)
  
        @document.count.should == 1
      end
  
      should "work with array as argument" do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
        @doc3 = @document.create({:first_name => 'Steph', :last_name => 'Nunemaker', :age => '26'})
        @document.destroy([@doc1.id, @doc2.id])
  
        @document.count.should == 1
      end
    end
  
    context "Destroying all documents" do
      setup do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
        @doc3 = @document.create({:first_name => 'Steph', :last_name => 'Nunemaker', :age => '26'})
      end
  
      should "remove all documents when given no conditions" do
        @document.destroy_all
        @document.count.should == 0
      end
  
      should "only remove matching documents when given conditions" do
        @document.destroy_all(:first_name => 'John')
        @document.count.should == 2
        @document.destroy_all(:age => 26)
        @document.count.should == 1
      end
  
      should "convert the conditions to mongo criteria" do
        @document.destroy_all(:age => [26, 27])
        @document.count.should == 1
      end
    end
  
    context "Counting documents in collection" do
      setup do
        @doc1 = @document.create({:first_name => 'John', :last_name => 'Nunemaker', :age => '27'})
        @doc2 = @document.create({:first_name => 'Steve', :last_name => 'Smith', :age => '28'})
        @doc3 = @document.create({:first_name => 'Steph', :last_name => 'Nunemaker', :age => '26'})
      end
  
      should "count all with no arguments" do
        @document.count.should == 3
      end
  
      should "return 0 if there are no documents in the collection" do
        @document.delete_all
        @document.count.should == 0
      end
  
      should "return 0 if the collection does not exist" do
        klass = Class.new do
          include MongoMapper::Document
          collection 'foobarbazwickdoesnotexist'
        end
  
        klass.count.should == 0
      end
  
      should "return count for matching documents if conditions provided" do
        @document.count(:age => 27).should == 1
      end
  
      should "convert the conditions to mongo criteria" do
        @document.count(:age => [26, 27]).should == 2
      end
    end
  
    context "Indexing" do
      setup do
        @document.collection.drop_indexes
      end
  
      should "allow creating index for a key" do
        index_name = nil
        lambda {
          index_name = @document.ensure_index :first_name
        }.should change { @document.collection.index_information.size }.by(1)
        
        index_name.should == 'first_name_1'
        index = @document.collection.index_information[index_name]
        index.should_not be_nil
        index.should include(['first_name', 1])
      end
  
      should "allow creating unique index for a key" do
        @document.collection.expects(:create_index).with(:first_name, true)
        @document.ensure_index :first_name, :unique => true
      end
  
      should "allow creating index on multiple keys" do
        index_name = nil
        lambda {
          index_name = @document.ensure_index [[:first_name, 1], [:last_name, -1]]
        }.should change { @document.collection.index_information.size }.by(1)
        
        index_name.should == 'first_name_1_last_name_-1'
        
        index = @document.collection.index_information[index_name]
        index.should_not be_nil
        index.should include(['first_name', 1])
        index.should include(['last_name', -1])
      end
  
      should "work with :index shortcut when defining key" do
        @document.expects(:ensure_index).with('father').returns(nil)
        @document.key :father, String, :index => true
      end
    end
  end # Document Class Methods
  
  context "Saving a new document" do
    setup do
      @doc = @document.new(:first_name => 'John', :age => '27')
      @doc.save
    end
  
    should "insert document into the collection" do
      @document.count.should == 1
    end
  
    should "assign an id for the document" do
      @doc.id.should_not be(nil)
      @doc.id.size.should == 24
    end
  
    should "save attributes" do
      @doc.first_name.should == 'John'
      @doc.age.should == 27
    end
  
    should "update attributes in the database" do
      from_db = @document.find(@doc.id)
      from_db.should == @doc
      from_db.first_name.should == 'John'
      from_db.age.should == 27
    end
  end
  
  context "Saving an existing document" do
    setup do
      @doc = @document.create(:first_name => 'John', :age => '27')
      @doc.first_name = 'Johnny'
      @doc.age = 30
      @doc.save
    end
  
    should "not insert document into collection" do
      @document.count.should == 1
    end
      
    should "update attributes" do
      @doc.first_name.should == 'Johnny'
      @doc.age.should == 30
    end
  
    should "update attributes in the database" do
      from_db = @document.find(@doc.id)
      from_db.first_name.should == 'Johnny'
      from_db.age.should == 30
    end
  end
  
  context "Calling update attributes on a new document" do
    setup do
      @doc = @document.new(:first_name => 'John', :age => '27')
      @doc.update_attributes(:first_name => 'Johnny', :age => 30)
    end
  
    should "insert document into the collection" do
      @document.count.should == 1
    end
  
    should "assign an id for the document" do
      @doc.id.should_not be(nil)
      @doc.id.size.should == 24
    end
  
    should "save attributes" do
      @doc.first_name.should == 'Johnny'
      @doc.age.should == 30
    end
  
    should "update attributes in the database" do
      from_db = @document.find(@doc.id)
      from_db.should == @doc
      from_db.first_name.should == 'Johnny'
      from_db.age.should == 30
    end
  end
  
  context "Updating an existing document using update attributes" do
    setup do
      @doc = @document.create(:first_name => 'John', :age => '27')
      @doc.update_attributes(:first_name => 'Johnny', :age => 30)
    end
  
    should "not insert document into collection" do
      @document.count.should == 1
    end
  
    should "update attributes" do
      @doc.first_name.should == 'Johnny'
      @doc.age.should == 30
    end
  
    should "update attributes in the database" do
      from_db = @document.find(@doc.id)
      from_db.first_name.should == 'Johnny'
      from_db.age.should == 30
    end
  end
  
  context "Destroying a document that exists" do
    setup do
      @doc = @document.create(:first_name => 'John', :age => '27')
      @doc.destroy
    end
  
    should "remove the document from the collection" do
      @document.count.should == 0
    end
  
    should "raise error if assignment is attempted" do
      lambda { @doc.first_name = 'Foo' }.should raise_error(TypeError)
    end
  end
  
  context "Destroying a document that is a new" do
    setup do
      setup do
        @doc = @document.new(:first_name => 'John Nunemaker', :age => '27')
        @doc.destroy
      end
  
      should "not affect collection count" do
        @document.collection.count.should == 0
      end
  
      should "raise error if assignment is attempted" do
        lambda { @doc.first_name = 'Foo' }.should raise_error(TypeError)
      end
    end
  end
  
  context "timestamping" do
    should "set created_at and updated_at on create" do
      doc = @document.new(:first_name => 'John', :age => 27)
      doc.created_at.should be(nil)
      doc.updated_at.should be(nil)
      doc.save
      doc.created_at.should_not be(nil)
      doc.updated_at.should_not be(nil)
    end
  
    should "set updated_at on update but leave created_at alone" do
      doc = @document.create(:first_name => 'John', :age => 27)
      old_created_at = doc.created_at
      old_updated_at = doc.updated_at
      doc.first_name = 'Johnny'
      doc.save
      doc.created_at.should == old_created_at
      doc.updated_at.should_not == old_updated_at
    end
  end
end