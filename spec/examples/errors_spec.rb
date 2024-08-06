RSpec.describe 'errors' do
  it 'raises an error when declare an attribute without message specification' do
    expect {
      Class.new(Pb::Serializer::Base) do
        attribute :body
      end
    }.to raise_error Pb::Serializer::MissingMessageTypeError
  end

  it 'raises an error when unknown option is specified' do
    expect {
      Class.new(Pb::Serializer::Base) do
        message TestFixture::Simple::Message

        attribute :body, foo: :bar
      end
    }.to raise_error Pb::Serializer::InvalidAttributeOptionError
  end

  it 'raises an error when unknown field is declared' do
    expect {
      Class.new(Pb::Serializer::Base) do
        message TestFixture::Simple::Message

        attribute :foo
      end
    }.to raise_error Pb::Serializer::UnknownFieldError
  end

  context 'when attribute declaration is missed' do
    let(:klass) do
      Class.new(Pb::Serializer::Base) do
        message TestFixture::Simple::Message
      end
    end

    before do
      config = Pb::Serializer::Configuration.new
      allow(Pb::Serializer).to receive(:configuration).and_return(config)

      Pb::Serializer.configure do |c|
        c.missing_field_behavior = missing_field_behavior
        c.logger = Logger.new(log_buffer)
      end
    end

    let(:log_buffer) { StringIO.new }
    subject { klass.new(Struct.new(:body).new('foo')).to_pb }

    context 'when missing_field_behavior is `raise`' do
      let(:missing_field_behavior) { :raise }

      it 'raises an error if missing_field_behavior is `raise`' do
        expect { subject }.to raise_error Pb::Serializer::MissingFieldError
      end
      it { expect(log_buffer.string).to be_empty }
    end

    context 'when missing_field_behavior is `warn`' do
      let(:missing_field_behavior) { :warn }

      it 'call logger.warn' do
        subject
        expect(log_buffer.string).not_to be_empty
      end
      it { is_expected.to be_a TestFixture::Simple::Message }
    end

    context 'when missing_field_behavior is `ignore`' do
      let(:missing_field_behavior) { :ignore }

      it { expect(log_buffer.string).to be_empty }
      it { is_expected.to be_a TestFixture::Simple::Message }
    end
  end

  it 'raises when set invalid param to missing_field_behavior config' do
    config = Pb::Serializer::Configuration.new
    expect { config.missing_field_behavior = :foobar }.to raise_error Pb::Serializer::InvalidConfigurationError
  end
end
