require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe SourcesController do
  describe "using import logic" do
    before(:each) do
      @venue = mock_model(Venue,
        :source => nil,
        :source= => true,
        :save! => true)

      @event = mock_model(Event,
        :title => "Super Event",
        :source= => true,
        :save! => true,
        :venue => @venue,
        :start_time => Time.now+1.week,
        :end_time => nil)

      @source = Source.new(:url => "http://my.url/")
      @source.stub!(:save!).and_return(true)
      @source.stub!(:to_events).and_return([@event])

      Source.stub!(:new).and_return(@source)
      Source.stub!(:find_or_create_by_url).and_return(@source)
    end

    it "should provide a way to create new sources" do
      get :new
      assigns(:source).should be_a_kind_of(Source)
      assigns(:source).should be_a_new_record
    end

    it "should save the source object after creating events" do
      # twice: create and save
      @source.should_receive(:save!).twice
      post :import
      flash[:success].should =~ /Imported/i
    end

    it "should assign newly created events to the source" do
      @event.should_receive(:save!)
      post :import
    end

    it "should assign newly created venues to the source" do
      @venue.should_receive(:save!)
      post :import
    end

    it "should limit the number of created events to list in the flash" do
      excess = 5
      events = (1..(SourcesController::MAXIMUM_EVENTS_TO_DISPLAY_IN_FLASH+excess))\
        .inject([]){|result,i| result << @event; result}
      @source.should_receive(:to_events).and_return(events)
      post :import
      flash[:success].should =~ /And #{excess} other events/si
    end

    it "should give a nice error message when given a bad URL" do
      @source.should_receive(:to_events).and_raise(OpenURI::HTTPError.new("bad_url", nil))
      errors = ActiveRecord::Errors.new(@source)
      errors.stub!(:full_messages).and_return(%w(bad))
      @source.should_receive(:errors).at_least(1).times.and_return(errors)
      post :import
      flash[:failure].should =~ /Unable to import: bad/
    end
  end
  
  
  describe "handling GET /sources" do

    before(:each) do
      @source = mock_model(Source)
      Source.stub!(:find).and_return([@source])
    end
  
    def do_get
      get :index
    end
  
    it "should be successful" do
      do_get
      response.should be_success
    end

    it "should render index template" do
      do_get
      response.should render_template('index')
    end
  
    it "should find all sources" do
      Source.should_receive(:find).with(:all).and_return([@source])
      do_get
    end
  
    it "should assign the found sources for the view" do
      do_get
      assigns[:sources].should == [@source]
    end
  end

  describe "handling GET /sources.xml" do

    before(:each) do
      @sources = mock("Array of Sources", :to_xml => "XML")
      Source.stub!(:find).and_return(@sources)
    end
  
    def do_get
      @request.env["HTTP_ACCEPT"] = "application/xml"
      get :index
    end
  
    it "should be successful" do
      do_get
      response.should be_success
    end

    it "should find all sources" do
      Source.should_receive(:find).with(:all).and_return(@sources)
      do_get
    end
  
    it "should render the found sources as xml" do
      @sources.should_receive(:to_xml).and_return("XML")
      do_get
      response.body.should == "XML"
    end
  end

  describe "handling GET /sources/1" do

    before(:each) do
      @source = mock_model(Source)
      Source.stub!(:find).and_return(@source)
    end
  
    def do_get
      get :show, :id => "1"
    end

    it "should be successful" do
      do_get
      response.should be_success
    end
  
    it "should render show template" do
      do_get
      response.should render_template('show')
    end
  
    it "should find the source requested" do
      Source.should_receive(:find).with("1").and_return(@source)
      do_get
    end
  
    it "should assign the found source for the view" do
      do_get
      assigns[:source].should equal(@source)
    end
  end

  describe "handling GET /sources/1.xml" do

    before(:each) do
      @source = mock_model(Source, :to_xml => "XML")
      Source.stub!(:find).and_return(@source)
    end
  
    def do_get
      @request.env["HTTP_ACCEPT"] = "application/xml"
      get :show, :id => "1"
    end

    it "should be successful" do
      do_get
      response.should be_success
    end
  
    it "should find the source requested" do
      Source.should_receive(:find).with("1").and_return(@source)
      do_get
    end
  
    it "should render the found source as xml" do
      @source.should_receive(:to_xml).and_return("XML")
      do_get
      response.body.should == "XML"
    end
  end

  describe "handling GET /sources/new" do

    before(:each) do
      @source = mock_model(Source)
      Source.stub!(:new).and_return(@source)
    end
  
    def do_get
      get :new
    end

    it "should be successful" do
      do_get
      response.should be_success
    end
  
    it "should render new template" do
      do_get
      response.should render_template('new')
    end
  
    it "should create an new source" do
      Source.should_receive(:new).and_return(@source)
      do_get
    end
  
    it "should not save the new source" do
      @source.should_not_receive(:save)
      do_get
    end
  
    it "should assign the new source for the view" do
      do_get
      assigns[:source].should equal(@source)
    end
  end

  describe "handling GET /sources/1/edit" do

    before(:each) do
      @source = mock_model(Source)
      Source.stub!(:find).and_return(@source)
    end
  
    def do_get
      get :edit, :id => "1"
    end

    it "should be successful" do
      do_get
      response.should be_success
    end
  
    it "should render edit template" do
      do_get
      response.should render_template('edit')
    end
  
    it "should find the source requested" do
      Source.should_receive(:find).and_return(@source)
      do_get
    end
  
    it "should assign the found Source for the view" do
      do_get
      assigns[:source].should equal(@source)
    end
  end

  describe "handling POST /sources" do

    before(:each) do
      @source = mock_model(Source, :to_param => "1")
      Source.stub!(:new).and_return(@source)
    end
    
    describe "with successful save" do
  
      def do_post
        @source.should_receive(:save).and_return(true)
        post :create, :source => {}
      end
  
      it "should create a new source" do
        Source.should_receive(:new).with({}).and_return(@source)
        do_post
      end

      it "should redirect to the new source" do
        do_post
        response.should redirect_to(source_url("1"))
      end
      
    end
    
    describe "with failed save" do

      def do_post
        @source.should_receive(:save).and_return(false)
        post :create, :source => {}
      end
  
      it "should re-render 'new'" do
        do_post
        response.should render_template('new')
      end
      
    end
  end

  describe "handling PUT /sources/1" do

    before(:each) do
      @source = mock_model(Source, :to_param => "1")
      Source.stub!(:find).and_return(@source)
    end
    
    describe "with successful update" do

      def do_put
        @source.should_receive(:update_attributes).and_return(true)
        put :update, :id => "1"
      end

      it "should find the source requested" do
        Source.should_receive(:find).with("1").and_return(@source)
        do_put
      end

      it "should update the found source" do
        do_put
        assigns(:source).should equal(@source)
      end

      it "should assign the found source for the view" do
        do_put
        assigns(:source).should equal(@source)
      end

      it "should redirect to the source" do
        do_put
        response.should redirect_to(source_url("1"))
      end

    end
    
    describe "with failed update" do

      def do_put
        @source.should_receive(:update_attributes).and_return(false)
        put :update, :id => "1"
      end

      it "should re-render 'edit'" do
        do_put
        response.should render_template('edit')
      end

    end
  end

  describe "handling DELETE /sources/1" do

    before(:each) do
      @source = mock_model(Source, :destroy => true)
      Source.stub!(:find).and_return(@source)
    end
  
    def do_delete
      delete :destroy, :id => "1"
    end

    it "should find the source requested" do
      Source.should_receive(:find).with("1").and_return(@source)
      do_delete
    end
  
    it "should call destroy on the found source" do
      @source.should_receive(:destroy)
      do_delete
    end
  
    it "should redirect to the sources list" do
      do_delete
      response.should redirect_to(sources_url)
    end
  end
end