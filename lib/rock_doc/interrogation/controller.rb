class RockDoc
  module Interrogation
    class Controller
      def self.interrogate_controller rock_doc, path, route_configs, serializer_configs, config
        config.path          = path
        config.routes        = route_configs
        config.resource_name = config.path.gsub(/^(#{rock_doc.global_config.namespaces.join('|')})\//, '').camelcase.singularize


        config.controller_class = begin
                                    Rails.application.routes.dispatcher("").send(:controller_reference, config.path)
                                  rescue NameError
                                    nil
                                  end

        config.resource_class   = config.resource_name.safe_constantize


        if config.controller_class.respond_to?(:permitted_params) && config.controller_class.permitted_params
          params_hash = config.controller_class.permitted_params
          params_hash[params_hash.keys.first] = params_hash[params_hash.keys.first].map do |attribute|
            type = config.resource_class.columns_hash[attribute].type.to_s.capitalize rescue "String"
            [attribute, type]
          end.to_h
          config.attributes_for_permitted_params ||= params_hash
        end

      end
    end
  end
end
