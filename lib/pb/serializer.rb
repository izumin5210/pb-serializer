require "pb/serializer/version"
require "the_pb"
require "computed_model"
require "google/protobuf/field_mask_pb"

require "pb/serializable"
require "pb/serializer/base"

module Pb
  module Serializer
    class Error < StandardError; end
    class InvalidConfigurationError < Error; end
    class MissingMessageTypeError < Error; end
    class UnknownFieldError < Error; end
    class ValidationError < Error; end
    class ConflictOneofError < Error; end
    class InvalidAttributeOptionError < Error; end
    class MissingFieldError < Error; end

    class Configuration
      # @!attribute logger
      #   @return [Logger]
      attr_accessor :logger
      # @!attribute [r] missing_field_behavior
      #   @return [:raise, :warn, :ignore] default: `:raise`
      attr_reader :missing_field_behavior

      def initialize
        self.missing_field_behavior = :raise
        self.logger = Logger.new(STDOUT)
      end

      # @param v [:raise, :warn, :ignore]
      # @return [void]
      def missing_field_behavior=(v)
        @missing_field_behavior = v

        unless %i(raise warn ignore).include?(v)
          raise InvalidConfigurationError, "missing_field_behavior #{v} is not allowed"
        end
      end
    end

    class << self
      # @example
      #   Pb::Serializer.configuration do |c|
      #     c.missing_field_behavior = :raise  # :raise, :warn or :ignore (default: :raise)
      #   end
      # @yield [c]
      # @yieldparam [Configuration] config
      # @return [void]
      def configure
        yield configuration
      end

      # @return [Pb::Serializer::Configuration]
      def configuration
        @configuration ||= Configuration.new
      end

      # @return [Logger]
      def logger
        configuration.logger
      end

      # @param descriptor [Google::Protobuf::Descriptor]
      def build_default_mask(descriptor)
        set =
          descriptor.each_with_object(Set[]) do |fd, m|
            case fd.type
            when :message
              case fd.submsg_name
              when "google.protobuf.Timestamp", 
                "google.protobuf.StringValue",
                "google.protobuf.Int32Value" ,
                "google.protobuf.Int64Value" ,
                "google.protobuf.UInt32Value",
                "google.protobuf.UInt64Value",
                "google.protobuf.FloatValue" ,
                "google.protobuf.DoubleValue",
                "google.protobuf.BoolValue"  ,
                "google.protobuf.BytesValue" then m << fd.name.to_sym
              else
                m << { fd.name.to_sym => -> { build_default_mask(fd.subtype) } }
              end
            else
              m << fd.name.to_sym
            end
          end
        set.to_a
      end

      # @param field_mask [Google::Protobuf::FieldMask]
      # @return [Array]
      def parse_field_mask(field_mask)
        unless field_mask.kind_of?(Google::Protobuf::FieldMask)
          raise ArgumentError, "expected Google::Protobuf::FieldMask, but got #{field_mask.class}"
        end

        field_mask.paths.map do |path|
          path.split(".").reverse.inject(nil) { |h, key| h.nil? ? key.to_sym : { key.to_sym => [h].compact } }
        end
      end

      # @param input [Google::Protobuf::FieldMask, Symbol, Array<(Symbol,Hash)>, Hash{Symbol=>(Array,Symbol,Hash,Proc)}, Proc]
      # @return [Hash{Symbol=>(Array,Hash,Proc)}]
      def normalize_mask(input)
        if input.kind_of?(Google::Protobuf::FieldMask)
          input = parse_field_mask(input)
        end

        input = input.call if input.kind_of?(Proc)
        input = [input] if input.kind_of?(Hash)

        normalized = {}
        Array(input).each do |el|
          case el
          when Symbol
            normalized[el] ||= []
          when Hash
            el.each do |k, v|
              v = v.call if v.kind_of?(Proc)
              v = [v] if v.kind_of?(Hash)
              normalized[k] ||= []
              normalized[k].push(*Array(v))
            end
          else
            raise "not supported field mask type: #{input.class}"
          end
        end

        normalized
      end
    end
  end
end
