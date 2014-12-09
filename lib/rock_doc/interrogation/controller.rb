class RockDoc
  module Interrogation
    class Controller
      def self.interrogate_controller doc: nil, path: nil, route_configurations: nil, serializer_configurations: nil, configuration: nil
        configuration.path           = path
        configuration.routes         = route_configurations
        configuration.resource_name  = configuration.path.gsub(/^(#{doc.global_configuration.namespaces.join('|')})\//, '').camelcase.singularize
        configuration.resource_class = configuration.resource_name.safe_constantize

        configuration.controller_class = begin
                                    Rails.application.routes.dispatcher("").send(:controller_reference, configuration.path)
                                  rescue NameError
                                    nil
                                  end




        if configuration.controller_class.respond_to?(:permitted_params) && configuration.controller_class.permitted_params
          params_hash = {}
          configuration.attributes_for_permitted_params ||= attribute_set params_hash, configuration, configuration.controller_class.permitted_params
        end
      end

      protected
      def self.attribute_set memo, configuration, working_set
        if working_set.is_a? Hash
          working_set.keys.each do |key|
            memo[key] = {}
            attribute_set memo[key], configuration, working_set[key]
          end
        elsif working_set.is_a? Array
          working_set.map do |k|
            if k.is_a? Hash
              memo = attribute_set memo, configuration, k
            else
              type = configuration.resource_class.columns_hash[k].type.to_s.capitalize rescue "String"
              memo[k] = type
            end
          end
        end

        memo
      end
    end
  end
end
