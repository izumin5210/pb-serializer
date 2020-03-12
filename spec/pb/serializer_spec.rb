require 'active_record'

RSpec.describe Pb::Serializer do
  class self::User < ActiveRecord::Base
   has_one :profile
   has_one :preference
  end
 
  class self::Profile < ActiveRecord::Base
    belongs_to :user
    has_many :works
  end

  class self::Work < ActiveRecord::Base
    belongs_to :proflie
  end

  class self::Preference < ActiveRecord::Base
    belongs_to :user
  end

  class self::UserSerializer < Pb::Serializer::Base
    message TestFixture::User

    delegates :name, :works, to: :profile

    depends on: { profile: :birthday }
    def age
      [Date.today, object.profile.birthday].map { |d| d.strftime('%Y%m%d').to_i }.then { |(t, b)| t - b } / 10000
    end

    depends on: { profile: :birthday }
    def birthday
      return unless object.profile&.birthday
      RSpec::ExampleGroups::PbSerializer::DateSerializer.new(object.profile&.birthday)
    end

    depends on: { profile: :avatar_url }
    def avatar_url
      object.profile.avatar_url || 'http://example.com/default_avatar.png'
    end

    depends on: { profile: :avatar_url }
    def original_avatar_url
      object.profile.avatar_url
    end
  end

  class self::WorkSerializer < Pb::Serializer::Base
    message TestFixture::Work

    def company; object.company; end
  end

  class self::DateSerializer < Pb::Serializer::Base
    message TestFixture::Date

    def year; object.year; end
    def month; object.month; end
    def day; object.day; end
  end

  before do
    ActiveRecord::Base.establish_connection(
      adapter:  "sqlite3",
      database: ":memory:",
    )
    m = ActiveRecord::Migration.new
    m.verbose = false
    m.create_table :users do |t|
      t.datetime :registered_at
    end
    m.create_table :preferences do |t|
      t.belongs_to :user
      t.string :email
    end
    m.create_table :profiles do |t|
      t.belongs_to :user
      t.string :name
      t.string :avatar_url
      t.date :birthday
    end
    m.create_table :works do |t|
      t.belongs_to :profile
      t.string :company
    end
  end

  after do
    m = ActiveRecord::Migration.new
    m.verbose = false
    m.drop_table :preferences
    m.drop_table :works
    m.drop_table :profiles
    m.drop_table :users
  end

  it "has a version number" do
    expect(Pb::Serializer::VERSION).not_to be nil
  end

  describe '#to_pb' do
    it 'serializes ruby object into protobuf message' do
      user = self.class::User.create(registered_at: Time.now)
      birthday = 3.years.ago
      profile = user.create_profile!(name: 'Masayuki Izumi', avatar_url: 'https://example.com/izumin5210/avatar', birthday: birthday)
      works = user.profile.works << self.class::Work.new(company: 'wanted')
      serializer = self.class::UserSerializer.new(user)
      pb = serializer.to_pb
      expect(pb).to be_kind_of TestFixture::User
      expect(pb.name).to eq profile.name
      expect(pb.avatar_url).to be_kind_of Google::Protobuf::StringValue
      expect(pb.avatar_url.value).to eq profile.avatar_url
      expect(pb.birthday).to be_kind_of TestFixture::Date
      expect(pb.birthday.year).to eq birthday.year
      expect(pb.birthday.month).to eq birthday.month
      expect(pb.birthday.day).to eq birthday.day
      expect(pb.age).to eq 3
      expect(pb.works).to be_kind_of Google::Protobuf::RepeatedField
      expect(pb.works[0]).to be_kind_of TestFixture::Work
      expect(pb.works[0].company).to eq works[0].company
    end
  end
end
