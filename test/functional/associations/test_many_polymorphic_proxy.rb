require 'test_helper'
require 'models'

class ManyPolymorphicProxyTest < Test::Unit::TestCase
  def setup
    clear_all_collections
  end
  
  should "default reader to empty array" do
    Room.new.messages.should == []
  end
  
  should "add type key to polymorphic class base" do
    Message.keys.keys.should include('_type')
  end
  
  should "allow adding to assiciation like it was an array" do
    room = Room.new
    room.messages << Enter.new
    room.messages.push Exit.new
    room.messages.concat Exit.new
    room.messages.size.should == 3
  end
  
  should "be able to replace the association" do
    room = Room.create(:name => 'Lounge')
    
    lambda {
      room.messages = [
        Enter.new(:body => 'John entered room'),
        Chat.new(:body => 'Heyyyoooo!'),
        Exit.new(:body => 'John exited room')
      ]
    }.should change { Message.count }.by(3)
    
    from_db = Room.find(room.id)
    from_db.messages.size.should == 3
    from_db.messages[0].body.should == 'John entered room'
    from_db.messages[1].body.should == 'Heyyyoooo!'
    from_db.messages[2].body.should == 'John exited room'
  end
  
  should "correctly store type when using <<, push and concat" do
    room = Room.new
    room.messages << Enter.new(:body => 'John entered the room')
    room.messages.push Exit.new(:body => 'John entered the room')
    room.messages.concat Chat.new(:body => 'Holla!')
    
    from_db = Room.find(room.id)
    from_db.messages[0]._type.should == 'Enter'
    from_db.messages[1]._type.should == 'Exit'
    from_db.messages[2]._type.should == 'Chat'
  end
  
  context "build" do
    should "assign foreign key" do
      room = Room.create
      message = room.messages.build
      message.room_id.should == room.id
    end
    
    should "assign _type" do
      room = Room.create
      message = room.messages.build
      message._type.should == 'Message'
    end
    
    should "allow assigning attributes" do
      room = Room.create
      message = room.messages.build(:body => 'Foo!')
      message.body.should == 'Foo!'
    end
  end
  
  context "create" do
    should "assign foreign key" do
      room = Room.create
      message = room.messages.create
      message.room_id.should == room.id
    end
    
    should "assign _type" do
      room = Room.create
      message = room.messages.create
      message._type.should == 'Message'
    end
    
    should "save record" do
      room = Room.create
      lambda {
        room.messages.create
      }.should change { Message.count }
    end
    
    should "allow passing attributes" do
      room = Room.create
      message = room.messages.create(:body => 'Foo!')
      message.body.should == 'Foo!'
    end
  end
  
  context "count" do
    should "work scoped to association" do
      room = Room.create
      3.times { room.messages.create }
      
      other_room = Room.create
      2.times { other_room.messages.create }
      
      room.messages.count.should == 3
      other_room.messages.count.should == 2
    end
    
    should "work with conditions" do
      room = Room.create
      room.messages.create(:body => 'Foo')
      room.messages.create(:body => 'Other 1')
      room.messages.create(:body => 'Other 2')
      
      room.messages.count(:body => 'Foo').should == 1
    end
  end
  
  context "Finding scoped to association" do
    setup do
      @lounge = Room.create(:name => 'Lounge')
      @lm1 = Message.create(:body => 'Loungin!')
      @lm2 = Message.create(:body => 'I love loungin!')
      @lounge.messages = [@lm1, @lm2]
      @lounge.save
      
      @hall = Room.create(:name => 'Hall')
      @hm1 = Message.create(:body => 'Do not fall in the hall')
      @hm2 = Message.create(:body => 'Hall the king!')
      @hm3 = Message.create(:body => 'Loungin!')
      @hall.messages = [@hm1, @hm2, @hm3]
      @hall.save
    end
    
    context "with :all" do
      should "work" do
        @lounge.messages.find(:all).should == [@lm1, @lm2]
      end
      
      should "work with conditions" do
        messages = @lounge.messages.find(:all, :conditions => {:body => 'Loungin!'})
        messages.should == [@lm1]
      end
      
      should "work with order" do
        messages = @lounge.messages.find(:all, :order => '$natural desc')
        messages.should == [@lm2, @lm1]
      end
    end
    
    context "with #all" do
      should "work" do
        @lounge.messages.all.should == [@lm1, @lm2]
      end
      
      should "work with conditions" do
        messages = @lounge.messages.all(:conditions => {'body' => 'Loungin!'})
        messages.should == [@lm1]
      end
      
      should "work with order" do
        messages = @lounge.messages.all(:order => '$natural desc')
        messages.should == [@lm2, @lm1]
      end
    end
    
    context "with :first" do
      should "work" do
        @lounge.messages.find(:first).should == @lm1
      end
      
      should "work with conditions" do
        message = @lounge.messages.find(:first, :conditions => {:body => 'I love loungin!'})
        message.should == @lm2
      end
    end
    
    context "with #first" do
      should "work" do
        @lounge.messages.first.should == @lm1
      end
      
      should "work with conditions" do
        message = @lounge.messages.first(:conditions => {:body => 'I love loungin!'})
        message.should == @lm2
      end
    end
    
    context "with :last" do
      should "work" do
        @lounge.messages.find(:last).should == @lm2
      end
      
      should "work with conditions" do
        message = @lounge.messages.find(:last, :conditions => {:body => 'Loungin!'})
        message.should == @lm1
      end
    end
    
    context "with #last" do
      should "work" do
        @lounge.messages.last.should == @lm2
      end
      
      should "work with conditions" do
        message = @lounge.messages.last(:conditions => {:body => 'Loungin!'})
        message.should == @lm1
      end
    end
    
    context "with one id" do
      should "work for id in association" do
        @lounge.messages.find(@lm2.id).should == @lm2
      end
      
      should "not work for id not in association" do
        lambda {
          @lounge.messages.find(@hm2.id)
        }.should raise_error(MongoMapper::DocumentNotFound)
      end
    end
    
    context "with multiple ids" do
      should "work for ids in association" do
        messages = @lounge.messages.find(@lm1.id, @lm2.id)
        messages.should == [@lm1, @lm2]
      end
      
      should "not work for ids not in association" do
        lambda {
          @lounge.messages.find(@lm1.id, @lm2.id, @hm2.id)
        }.should raise_error(MongoMapper::DocumentNotFound)
      end
    end
    
    context "with #paginate" do
      setup do
        @messages = @hall.messages.paginate(:per_page => 2, :page => 1, :order => '$natural asc')
      end
      
      should "return total pages" do
        @messages.total_pages.should == 2
      end
      
      should "return total entries" do
        @messages.total_entries.should == 3
      end
      
      should "return the subject" do
        @messages.should == [@hm1, @hm2]
      end
    end
  end
end