module Application
	self < class
		attr_accessor :config
  end
	config = Hashie::Mash.new
end