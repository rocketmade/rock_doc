class RockDoc
  module Interrogation
    class ActiveModelSerializer
      def self.interrogate_serialization doc: nil, resource_configuration: nil, configuration: nil
        configuration.serializer          = resource_configuration.serializer
        configuration.resource_class      = resource_configuration.resource_class
        configuration.resource_name       = resource_configuration.resource_class.name.underscore.humanize
        configuration.configuration_name  = resource_configuration.configuration_name
        configuration.attributes_for_json = serializer_to_attributes doc, configuration.serializer, configuration.resource_class
      end

      def self.serializer_to_attributes doc, serializer, resource_class
        attributes   = serializer.schema[:attributes].dup
        associations = serializer.schema.fetch(:associations, {}).reduce({}) { |memo, kvp|
          key = nil

          begin
            key = resource_class.reflect_on_association(kvp.first).class_name
          rescue NoMethodError
          end

          if key
            if kvp.last.keys.include? :has_many
              memo[kvp.first] = doc.t("json.resource_array", resource: key, resources: key.pluralize)
            else
              memo[kvp.first] = doc.t("json.resource_object", resource: key, resources: key.pluralize)
            end
          end
          memo
        }

        attributes.merge associations
      end

      def self.interrogate_controller doc: nil, path: nil, route_configurations: nil, serializer_configurations: nil, configuration: nil
        if configuration.resource_class && configuration.resource_class < ActiveRecord::Base && configuration.resource_class.respond_to?(:active_model_serializer)
          configuration.serializer_configuration ||= serializer_configurations.find do |sc|
            sc.serializer == configuration.resource_class.active_model_serializer
          end

          if configuration.serializer_configuration
            configuration.attributes_for_json ||= configuration.serializer_configuration.attributes_for_json
            configuration.attributes_for_json ||= serializer_to_attributes doc, configuration.serializer_configuration.serializer, configuration.resource_class
          end
        end
      end
    end
  end
end
