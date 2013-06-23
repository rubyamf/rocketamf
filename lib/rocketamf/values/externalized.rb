module RocketAMF
  module Values
    class AbstractMessage
      ExternalizedFields = [
        %w[ body clientId destination headers messageId timestamp timeToLive ],
        %w[ clientIdBytes messageIdBytes ]
      ]

      def to_pretty_uuid(obj)
        if obj.is_a?(StringIO)
          "%08X-%04X-%04X-%04X-%08X%04X" % obj.string.unpack("NnnnNn")
        else
          nil
        end
      end

      def to_binary_uuid(obj)
        if obj.is_a?(String) && obj.size == 36
          obj.gsub('-','').scan(/../).map {|pair| pair.hex}.pack('C*')
        else
          nil
        end
      end

      def populate(source, fields)
        flags = []
        loop do
          flags << source.read(1).unpack('C').first
          break if flags.last < 128
        end

        if fields && !fields.empty?
          fields.each_with_index do |list, i|
            list.each_with_index do |name, j|
              if flags[i].ord[j] > 0
                data = RocketAMF.deserialize(source, 3)
                send("#{name}=", data)
              end
            end
          end
        end
      end

      def internalize(source)
        populate(source, ExternalizedFields)
      end

      def clientId=(obj)
        @clientIdBytes = to_binary_uuid(obj)
        @clientId = obj
      end

      def clientIdBytes=(obj)
        @clientId = to_pretty_uuid(obj)
        @clientIdBytes = obj
      end

      def messageId=(obj)
        @messageIdBytes = to_binary_uuid(obj)
        @messageId = obj
      end

      def messageIdBytes=(obj)
        @messageId = to_pretty_uuid(obj)
        @messageIdBytes = obj
      end
    end

    class AsyncMessage
      ExternalizedFields = [
        %w[ correlationId correlationIdBytes ],
      ]

      def internalize(source)
        super
        populate(source, ExternalizedFields)
      end

      def correlationId=(obj)
        @correlationIdBytes = to_binary_uuid(obj)
        @correlationId = obj
      end

      def correlationIdBytes=(obj)
        @correlationId = to_pretty_uuid(obj)
        @correlationIdBytes = obj
      end
    end

    class AcknowledgeMessage
      ExternalizedFields = nil

      def internalize(source)
        super
        populate(source, ExternalizedFields)
      end
    end
  end
end
