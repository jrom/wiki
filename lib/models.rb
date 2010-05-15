class Page < ActiveRecord::Base

  versioned

  before_validation :check_slash

  validates_presence_of :url
  validates_length_of :url, :minimum => 1
  validates_uniqueness_of :url
  validates_exclusion_of :url, :in => ["/e", "/p", "/n", "/r"], :message => "URL {{value}} is reserved."
  validates_presence_of :title, :body

  LOCKING_PERIOD = 1.minute
  def locked?
    self.locked_at && self.locked_at +  LOCKING_PERIOD > Time.now
  end

  private
  # We add the first slash if it wasn't there
  def check_slash
    unless url && !self.url.empty? && self.url[0..0] == "/"
      self.url = "/#{self.url}"
    end
  end

end
