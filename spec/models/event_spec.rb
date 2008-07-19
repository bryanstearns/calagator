require File.dirname(__FILE__) + '/../spec_helper'

describe Event do
  before(:each) do
    @event = Event.new
  end

  describe "in general"  do

    it "should be valid" do
      event = Event.new(:title => "Event title", :start_time => Time.parse('2008.04.12'))
      event.should be_valid
    end

    it "should add a http:// prefix to urls without one" do
      event = Event.new(:title => "Event title", :start_time => Time.parse('2008.04.12'), :url => 'google.com')
      event.should be_valid
    end
  end
  
  describe "when checking time status" do
    fixtures :events
    
    it "should be old if event ended before today" do 
      events(:old_event).should be_old
    end
    
    it "should be current if event is happening today" do 
      events(:tomorrow).should be_current
    end
    
    it "should be ongoing if it began before today but ends today or later" do
      events(:ongoing_event).should be_ongoing
    end
    
  end

  describe "dealing with tags" do
    before(:each) do
      @tags = "some, tags"
      @event.title = "Tagging Day"
      @event.start_time = Time.now
    end

    it "should be taggable" do
      Tag # need to reference Tag class in order to load it.
      @event.tag_list.should == ""
    end

    it "should tag itself if it is an extant record" do
      # On next line, please retain the space between the "?" and ")";
      # it solves a fold issue in the SciTE text editor
      @event.stub!(:new_record? ).and_return(false)
      @event.should_receive(:tag_with).with(@tags).and_return(@event)
      @event.tag_list = @tags
    end

    it "should just cache tagging if it is a new record" do
      @event.should_not_receive(:save)
      @event.should_not_receive(:tag_with)
      @event.new_record?.should == true
      @event.tag_list = @tags
      @event.tag_list.should == @tags
    end

    it "should tag itself when saved for the first time if there are cached tags" do
      @event.new_record?.should == true
      @event.should_receive(:tag_with).with(@tags).and_return(@event)
      @event.tag_list = @tags
      @event.save
    end

  end

  describe "when parsing" do

    before(:each) do

      @basic_hcal = read_sample('hcal_basic.xml')
      @basic_venue = mock_model(Venue, :title => 'Argent Hotel, San Francisco, CA')
      @basic_event = Event.new(
        :title => 'Web 2.0 Conference',
        :url => 'http://www.web2con.com/',
        :start_time => Time.parse('2007-10-05'),
        :end_time => nil,
        :venue => @basic_venue)
    end

    it "should parse an AbstractEvent into an Event" do
      event = Event.new(:title => "EventTitle",
                        :description => "EventDescription",
                        :start_time => Time.parse("2008-05-20"),
                        :end_time => Time.parse("2008-05-22"))
      Event.should_receive(:new).and_return(event)

      abstract_event = SourceParser::AbstractEvent.new("EventTitle", "EventDescription", Time.parse("2008-05-20"), Time.parse("2008-05-22"))

      Event.from_abstract_event(abstract_event).should == event
    end

    it "should parse an Event into an hCalendar" do
      actual_hcal = @basic_event.to_hcal
      actual_hcal.should =~ Regexp.new(@basic_hcal.gsub(/\s+/, '\s+')) # Ignore spacing changes
    end

    it "should parse an Event into an iCalendar" do
      actual_ical = @basic_event.to_ical

      abstract_events = SourceParser.to_abstract_events(:content => actual_ical, :skip_old => false)

      abstract_events.size.should == 1
      abstract_event = abstract_events.first
      abstract_event.title.should == @basic_event.title
      abstract_event.url.should == @basic_event.url

      # TODO implement venue generation
      #abstract_event.location.title.should == @basic_event.venue.title
      abstract_event.location.should be_nil
    end

    it "should parse an Event into an iCalendar without a URL and generate it" do
      generated_url = "http://foo.bar/"
      @basic_event.url = nil
      actual_ical = @basic_event.to_ical(:url_helper => lambda{|event| generated_url})

      abstract_events = SourceParser.to_abstract_events(:content => actual_ical, :skip_old => false)

      abstract_events.size.should == 1
      abstract_event = abstract_events.first
      abstract_event.title.should == @basic_event.title
      abstract_event.url.should == generated_url

      # TODO implement venue generation
      #abstract_event.location.title.should == @basic_event.venue.title
      abstract_event.location.should be_nil
    end

  end

  describe "when processing date" do

    # TODO: write integration specs for the following 2 tests
    it "should find all events with duplicate titles" do
      Event.should_receive(:find_by_sql).with("SELECT DISTINCT a.* from events a, events b WHERE a.id <> b.id AND ( a.title = b.title ) ORDER BY a.title")
      Event.find_duplicates_by(:title)
    end

    it "should find all events with duplicate titles and urls" do
      Event.should_receive(:find_by_sql).with("SELECT DISTINCT a.* from events a, events b WHERE a.id <> b.id AND ( a.title = b.title AND a.url = b.url ) ORDER BY a.title,a.url")
      Event.find_duplicates_by([:title,:url])
    end

    it "should fail to validate if end_time is earlier than start time " do
      @event.start_time = Time.now
      @event.end_time = @event.start_time - 2.hours
      @event.save.should be_false
      @event.should have(1).error_on(:end_time)
    end

  end

  describe "when finding by dates" do

    before(:all) do
      @today_midnight = Time.today
      @yesterday = @today_midnight.yesterday
      @tomorrow = @today_midnight.tomorrow

      @started_before_today_and_ends_after_today = Event.create(
        :title => "Event in progress",
        :start_time => @yesterday,
        :end_time => @tomorrow)

      @started_midnight_and_continuing_after = Event.create(
        :title => "Midnight start",
        :start_time => @today_midnight,
        :end_time => @tomorrow)

      @started_and_ended_yesterday = Event.create(
        :title => "Yesterday start",
        :start_time => @yesterday,
        :end_time => @yesterday.end_of_day)

      @started_today_and_no_end_time = Event.create(
        :title => "nil end time",
        :start_time => @now,
        :end_time => nil)

      @starts_and_ends_tomorrow = Event.create(
        :title => "starts and ends tomorrow",
        :start_time => @tomorrow,
        :end_time => @tomorrow.end_of_day)

      @starts_after_tomorrow = Event.create(
        :title => "Starting after tomorrow",
        :start_time => @tomorrow + 1.day)
    end

    describe "for overview" do
      # TODO:  consider writing the following specs as view specs
      # either in addition to, or instead of, model specs

      before(:all) do
        @overview = Event.select_for_overview
      end

      describe "events today" do
        it "should include events that started before today and end after today" do
          @overview[:today].should include(@started_before_today_and_ends_after_today)
        end

        it "should include events that started earlier today" do
          @overview[:today].should include(@started_midnight_and_continuing_after)
        end

        it "should not include events that ended before today" do
          @overview[:today].should_not include(@started_and_ended_yesterday)
        end

        it "should not include events that start tomorrow" do
          @overview[:today].should_not include(@starts_and_ends_tomorrow)
        end
      end

      describe "events tomorrow" do
        it "should not include events that start after tomorrow" do
          @overview[:tomorrow].should_not include(@starts_after_tomorrow)
        end
      end
    end

    describe "for future events" do
      before(:all) do
        @future_events = Event.find_future_events
      end

      it "should include events that started earlier today" do
        @future_events.should include(@started_midnight_and_continuing_after)
      end

      it "should include events with no end time that started today" do
        @future_events.should include(@started_today_and_no_end_time)
      end

      it "should include events that started before today and ended after today" do
        events = Event.find_future_events("start_time")
        events.should include(@started_before_today_and_ends_after_today)
      end

      it "should include events with no end time that started today" do
        @future_events.should include(@started_today_and_no_end_time)
      end

      it "should not include events that ended before today" do
        @future_events.should_not include(@started_and_ended_yesterday)
      end
    end

    describe "for date range" do
      it "should include events that started earlier today" do
        events = Event.find_by_dates(@today_midnight, @tomorrow, order = "start_time")
        events.should include(@started_midnight_and_continuing_after)
      end

      it "should include events that started before today and end after today" do
        events = Event.find_by_dates(@today_midnight, @tomorrow, order = "start_time")
        events.should include(@started_before_today_and_ends_after_today)
      end

      it "should not include past events" do
        events = Event.find_by_dates(@today_midnight, @tomorrow, order = "start_time")
        events.should_not include(@started_and_ended_yesterday)
      end

      it "should exclude events that start after the end of the range" do
        events = Event.find_by_dates(@tomorrow, @tomorrow, order = "start_time")
        events.should_not include(@started_today_and_no_end_time)
      end
    end
  end

  describe "when searching" do
    # TODO figure out sane way to write spec for Event.search
    it "should find events" do
      solr_response = mock_model(Object, :results => [])
      solr_return = mock_model(Object, :response => solr_response)
      Event.should_receive(:find_by_solr).and_return(solr_response)

      Event.search("myquery").should be_empty
    end

    it "should find events and group them" do
      current_event = mock_model(Event, :current? => true, :duplicate_of_id => nil)
      past_event = mock_model(Event, :current? => false, :duplicate_of_id => nil)
      solr_response = mock_model(Object, :results => [current_event, past_event])
      solr_return = mock_model(Object, :response => solr_response)
      Event.should_receive(:find_by_solr).and_return(solr_response)

      Event.search_grouped_by_currentness("myquery").should == {
        :current => [current_event],
        :past    => [past_event],
      }
    end
  end

  describe "when associating with venues" do

    before(:each) do
      @venue = mock_model(Venue, :title => "MyVenue", :duplicate? => false)
    end

    it "should not change a venue to a nil venue" do
      @event.associate_with_venue(nil).should be_nil
    end

    it "should associate a venue if one wasn't set before" do
      @event.associate_with_venue(@venue).should == @venue
    end

    it "should change an existing venue to a different one" do
      @event.venue = mock_model(Venue, :title => "OtherVenue")

      @event.associate_with_venue(@venue).should == @venue
    end

    it "should not change a venue if associated with one of same name" do
      venue2 = mock_model(Venue, :title => "MyVenue")
      @event.venue = venue2

      @event.associate_with_venue(@venue).should == venue2
    end

    it "should clear an existing venue if given a nil venue" do
      @event.venue = @venue

      @event.associate_with_venue(nil).should be_nil
      @event.venue.should be_nil
    end

    it "should associate venue by title" do
      Venue.should_receive(:find_or_initialize_by_title).and_return(@venue)

      @event.associate_with_venue(@venue.title).should == @venue
    end

    it "should associate venue by id" do
      Venue.should_receive(:find).and_return(@venue)

      @event.associate_with_venue(1234).should == @venue
    end

    it "should raise an exception if associated with an unknown type" do
      lambda { @event.associate_with_venue(mock_model(SourceParser)) }.should raise_error(TypeError)
    end
  end

  describe "when finding duplicates" do
    it "should find duplicates by type" do
      pending # Event.find_duplicates_by_type
    end
  end
end