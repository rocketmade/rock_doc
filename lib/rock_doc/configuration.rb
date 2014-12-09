class RockDoc
  module Configuration
    class Global < Struct.new(:title, :toc, :global_block, :namespaces, :app_name, :renderer,
                              :interrogators
                             )
    end

    class Serializer < Struct.new(:resource_name, :resource_class, :json_representation,
                                  :notes, :attributes_for_json, :serializer, :nodoc,
                                  :configuration_name)
    end

    class Controller < Struct.new(:path, :resource_name,
                                  :resource_class, :controller_class,
                                  :serializer_config, :routes,
                                  :json_representation, :permitted_params,
                                  :notes, :attributes_for_json,
                                  :attributes_for_permitted_params, :action_configs,
                                  :nodoc
                                 )
      def action name, &block
        self.action_blocks[name] = block
      end

      def action_blocks
        @action_blocks ||= {}.with_indifferent_access
      end
    end

    class Action < Struct.new(:action, :description, :verb, :pathspec,
                              :controller_config, :notes,
                              :scopes, :nodoc
                             )
    end

    class AppControllerConfiguration < Struct.new(:namespace, :block)
    end

    class Route < Struct.new(:controller_path, :action, :verb, :path)
    end

    class Resource < Struct.new(:resource_class, :serializer, :configuration_name)
    end
  end
end
