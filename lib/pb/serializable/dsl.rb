require 'pb/serializable/dsl/attribute'
require 'pb/serializable/dsl/oneof'

module Pb
  module Serializable
    module Dsl
      # @param klass [Class] Protobuf message class
      # @return [void]
      def message(klass)
        self.__pb_serializer_message_class = klass
      end

      # @param name [Symbol] An attribute name
      # @param opts [Hash] options
      # @option opts [Boolean] :allow_nil Set true if this attribute allow to be nil
      # @option opts [Class] :serializer A serializer class for this attribute
      # @option opts [String, Symbol, Proc] :if A method, proc or string to call to determine to serialize this field
      # @return [void]
      # @raise [Pb::Serializer::MissingMessageTypeError] if this class has not been called {#message}
      # @raise [Pb::Serializer::UnknownFieldError] if the field does not defined in .proto
      # @raise [Pb::Serializer::InvalidAttributeOptionError] if unknown options are passed
      def attribute(name, opts = {})
        raise ::Pb::Serializer::MissingMessageTypeError, "message specification is missed" unless __pb_serializer_message_class

        fd = __pb_serializer_message_class.descriptor.find { |fd| fd.name.to_sym == name }

        raise ::Pb::Serializer::UnknownFieldError, "#{name} is not defined in #{ __pb_serializer_message_class.name}" unless fd

        attr = Attribute.new(
          name: name,
          options: opts,
          field_descriptor: fd,
          oneof: @current_oneof&.name,
        )

        __pb_serializer_attr_by_name[name] = attr

        unless method_defined?(attr.name)
          define_method attr.name do
            primary_object.public_send(attr.name)
          end
        end
      end

      # @param names [Array<Symbol>] Attribute names to be ignored
      # @return [void]
      # @example Ignore attributes
      #   ignore :deprecated_field, :not_implemented_field
      def ignore(*names)
        names.each do |name|
          attribute name, ignore: true
        end
      end

      # @param name [Symbol] An oneof attribute name
      # @param allow_nil [Boolean] Set true if this oneof attribute allow to be nil
      # @return [void]
      # @example Define oneof attributes
      #   oneof :test_oneof do
      #     attribute :name
      #     attribute :sub_message
      #   end
      def oneof(name, allow_nil: false)
        @current_oneof = Oneof.new(
          name: name,
          allow_nil: allow_nil,
          attributes: [],
        )
        yield
        __pb_serializer_oneof_by_name[name] = @current_oneof
        @current_oneof = nil
      end
    end
  end
end
