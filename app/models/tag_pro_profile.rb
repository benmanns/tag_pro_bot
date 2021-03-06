class TagProProfile < ActiveRecord::Base
  belongs_to :user

  validates :user_id, uniqueness: true
  validates :uid, uniqueness: { scope: :server }, presence: true
  validates :server, presence: true
  validate :flair_page_must_work

  URL_REGEX = /\A(?:http:\/\/)?tagpro-([a-z]+).koalabeast.com\/profile\/([\da-f]{24})\z/

  after_destroy :update_user_class
  after_save :update_user_class, on: :update
  before_validation :assign_confirmation_token

  def update_user_class
    user.update_attributes flair_class: nil if destroyed? || !flairs.map(&:flair_class).include?(user.flair_class)
  end

  def assign_confirmation_token
    self.confirmation_token ||= SecureRandom.hex(4)
  end

  def url
    "http://tagpro-#{server}.koalabeast.com/profile/#{uid}" if server && uid
  end

  def url=(url)
    if url =~ URL_REGEX
      self.server = $1
      self.uid = $2
    end
  end

  def flair_page
    @flair_page ||= begin
      agent = Mechanize.new
      agent.follow_redirect = false
      page = agent.get(url)
      raise unless page.code =~ /\A[234]/
      FlairPage.new(code: page.code, content: page.content)
    rescue
      nil
    end
  end

  def flair_page_must_work
    page = flair_page
    if page.nil?
      errors.add(:url, "couldn't be processed")
    elsif page.code == "302"
      errors.add(:url, "doesn't exist")
    end
  end

  delegate :flairs, to: :flair_page
  delegate :name, to: :flair_page
  delegate :display_name, to: :flair_page

  def confirmed?
    confirmed_at?
  end

  def name_with_token
    "#{name[0, 3]}-#{confirmation_token}"
  end

  def verify!
    return true if confirmed?
    return false unless confirmation_token.present?

    @flair_page = nil

    if display_name.include? confirmation_token
      update_attributes confirmed_at: Time.now
    else
      false
    end
  end
end
