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
          params_hash = configuration.controller_class.permitted_params
          params_hash[params_hash.keys.first] = params_hash[params_hash.keys.first].map do |attribute|
            type = configuration.resource_class.columns_hash[attribute].type.to_s.capitalize rescue "String"
            [attribute, type]
          end.to_h
          configuration.attributes_for_permitted_params ||= params_hash
        end
      end
    end
  end
end
