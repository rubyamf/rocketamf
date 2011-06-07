module RocketAMF
  module Values
    class AbstractMessage
      ExternalizedFields = [
        %w[ body clientId destination headers messageId timestamp timeToLive ],
        %w[ clientIdBytes messageIdBytes ]
      ]

      def to_uuid(obj)
        "%08X-%04X-%04X-%04X-%08X%04X" % obj.to_s.unpack("NnnnNn")
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

      def clientIdBytes=(obj)
        @clientId = to_uuid(obj)
        @clientIdBytes = obj
      end

      def messageIdBytes=(obj)
        @messageId = to_uuid(obj)
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

      def correlationIdBytes=(obj)
        @correlationId = to_uuid(obj)
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
