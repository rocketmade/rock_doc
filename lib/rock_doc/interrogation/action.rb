class RockDoc
  module Interrogation
    class Action
      def self.interrogate_action rock_doc, controller_config, route, config
        config.action = route.action
        config.description = rock_doc.action_description config: controller_config, action: config.action
        config.verb = route.verb
        config.pathspec = route.path.gsub(/\(?.:format\)?/, '.json')
        config.controller_config = controller_config

        if config.action.to_s == "index"
          scopes = controller_config.controller_class.scopes_configuration
          config.scopes = scopes.reduce({}) do |memo, kvp|
            key = kvp.first
            value = kvp.last
            if value[:type] == :hash
              value[:using].each do |sub_key|
                memo["#{key}[#{sub_key}]"] = rock_doc.scope_description scope: "#{key}[#{sub_key}]", config: controller_config, default: value[:default], type: value[:type]
              end
            else
              memo[key.to_s] = rock_doc.scope_description scope: key, config: controller_config, default: value[:default], type: value[:type]
            end

            memo
          end
        end
      end
    end
  end
end
