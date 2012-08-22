# Setup DataMapper here:
#
DataMapper.setup(:default, "sqlite://#{File.join(File.dirname(__FILE__), '..')}/tracker.db")
