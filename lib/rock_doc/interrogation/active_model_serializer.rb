class RockDoc
  module Interrogation
    class ActiveModelSerializer
      def self.interrogate_serialization rock_doc, serializer_config, config
        config.serializer          = serializer_config.serializer
        config.resource_class      = serializer_config.resource_class
        config.resource_name       = serializer_config.resource_class.name.underscore.humanize
        config.configuration_name  = serializer_config.configuration_name
        config.attributes_for_json = serializer_to_attributes rock_doc, config.serializer, config.resource_class
      end

      def self.serializer_to_attributes rock_doc, serializer, resource_class
        attributes = serializer.schema[:attributes].dup
        associations = serializer.schema.fetch(:associations, {}).reduce({}) { |memo, kvp|
          key = nil

          begin
            key = resource_class.reflect_on_association(kvp.first).class_name
          rescue NoMethodError
          end

          if key
            if kvp.last.keys.include? :has_many
              memo[kvp.first] = rock_doc.t("json.resource_array", resource: key, resources: key.pluralize)
            else
              memo[kvp.first] = rock_doc.t("json.resource_object", resource: key, resources: key.pluralize)
            end
          end
          memo
        }

        attributes.merge associations
      end

      def self.interrogate_controller rock_doc, path, route_configs, serializer_configs, config
        if config.resource_class && config.resource_class < ActiveRecord::Base && config.resource_class.respond_to?(:active_model_serializer)
          config.serializer_config ||= serializer_configs.find do |sc|
            sc.serializer == config.resource_class.active_model_serializer
          end

          if config.serializer_config
            config.attributes_for_json ||= config.serializer_config.attributes_for_json
            config.attributes_for_json ||= serializer_to_attributes rock_doc, config.serializer_config.serializer, config.resource_class
          end
        end
      end
    end
  end
end
