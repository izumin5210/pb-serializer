require "active_record"

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

    attribute :id,            required: true
    attribute :registered_at, required: true
    attribute :name,          required: true
    attribute :avatar_url
    attribute :birthday
    attribute :age

    attribute :works,      required: true
    attribute :preference, required: true

    delegates :name, :works, :birthday, to: :profile

    depends on: { profile: :birthday }
    def age
      return nil if object&.profile&.birthday.nil?
      [Date.today, object.profile.birthday].map {|d| d.strftime("%Y%m%d").to_i }.yield_self {|(t, b)| t - b } / 10000
    end

    depends on: { profile: :avatar_url }
    def avatar_url
      object.profile.avatar_url || "http://example.com/default_avatar.png"
    end

    depends on: { profile: :avatar_url }
    def original_avatar_url
      object.profile.avatar_url
    end
  end

  class self::WorkSerializer < Pb::Serializer::Base
    message TestFixture::Work

    attribute :company, required: true
  end

  class self::PreferenceSerializer < Pb::Serializer::Base
    message TestFixture::Preference

    attribute :email, required: true
  end

  class self::DateSerializer < Pb::Serializer::Base
    message TestFixture::Date

    attribute :year,  required: true
    attribute :month, required: true
    attribute :day,   required: true
  end

  before do
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
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

  describe "#to_pb" do
    it "serializes ruby object into protobuf message" do
      user = self.class::User.create(registered_at: Time.now)
      profile = user.create_profile!(
        name: "Masayuki Izumi",
        avatar_url: "https://example.com/izumin5210/avatar",
        birthday: Date.new(1993, 2, 10),
      )
      user.create_preference!(
        email: 'izumin5210@example.com'
      )
      serializer = self.class::UserSerializer.new(user)
      pb = serializer.to_pb
      expect(pb).to be_kind_of TestFixture::User
      expect(pb.name).to eq profile.name
      expect(pb.registered_at).to be_kind_of Google::Protobuf::Timestamp
      expect(pb.registered_at.seconds).to eq user.registered_at.to_i
      expect(pb.avatar_url).to be_kind_of Google::Protobuf::StringValue
      expect(pb.avatar_url.value).to eq profile.avatar_url
      expect(pb.birthday).to be_kind_of TestFixture::Date
      expect(pb.birthday.year).to eq 1993
      expect(pb.birthday.month).to eq 2
      expect(pb.birthday.day).to eq 10
    end

    it "raises a validation error when required attriutes are blank" do
      user = self.class::User.create(registered_at: Time.now)
      user.create_profile!
      serializer = self.class::UserSerializer.new(user)

      expect { p serializer.to_pb }.to raise_error ::Pb::Serializer::ValidationError
    end
  end
end
