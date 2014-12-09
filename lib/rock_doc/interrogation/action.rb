class RockDoc
  module Interrogation
    class Action
      def self.interrogate_action doc: nil, controller_configuration: nil, route: nil, configuration: nil
        configuration.action      = route.action
        configuration.description = doc.action_description configuration: controller_configuration, action: configuration.action
        configuration.verb        = route.verb
        configuration.pathspec    = route.path.gsub(/\(?.:format\)?/, '.json')

        configuration.controller_configuration = controller_configuration

        if configuration.action.to_s == "index"
          scopes = controller_configuration.controller_class.scopes_configuration
          configuration.scopes = scopes.reduce({}) do |memo, kvp|
            key = kvp.first
            value = kvp.last
            if value[:type] == :hash
              value[:using].each do |sub_key|
                memo["#{key}[#{sub_key}]"] = doc.scope_description scope: "#{key}[#{sub_key}]", configuration: controller_configuration, default: value[:default], type: value[:type]
              end
            else
              memo[key.to_s] = doc.scope_description scope: key, configuration: controller_configuration, default: value[:default], type: value[:type]
            end

            memo
          end
        end
      end
    end
  end
end
