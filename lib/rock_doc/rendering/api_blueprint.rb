module RockDoc::Rendering
  class ApiBlueprint
    delegate :t, :t!, to: :rock_doc
    delegate :global_configuration, to: :rock_doc

    attr_accessor :resource_configurations, :controller_configurations, :serializer_configurations, :rock_doc

    def render doc: required, controller_configurations: required, serializer_configurations: required
      self.rock_doc                  = doc
      self.controller_configurations = controller_configurations
      self.serializer_configurations = serializer_configurations

      self.resource_configurations = {}
      self.controller_configurations.map do |config|
        resource_configurations[config.resource_name] ||= {}
        resource_configurations[config.resource_name][:controller] = config
      end
      self.serializer_configurations.map do |config|
        resource_configurations[config.resource_name] ||= {}
        resource_configurations[config.resource_name][:serializer] = config
      end

      md = ["FORMAT: 1A\n"]

      md << title_line(global_configuration.title, 1)

      md << "\n\n"

      if global_configuration.global_block.present?
        md << global_configuration.global_block
        md << "\n"
      end

      md << render_resources
      md.join("\n")
    end

    def supported_json_types
      %w(String Integer Decimal Datetime Text Boolean)
    end

    def title_line title, depth
      '#' * depth + ' ' + title
    end

    def present_json hash
      json = JSON.pretty_generate(hash)

      json.gsub!(/"(\[|\{)/, '\1')
      json.gsub!(/(\]|\})"/, '\1')

      json.gsub!(/:\ "(#{supported_json_types.join('|').downcase})"/i).each do |match|
        ": #{match.gsub(':', '').gsub('"', '').strip.capitalize}"
      end
      json
    end

    def render_resources
      results = []

      @resource_configurations.each do |resource_name, configuration|
        results << render_resource(resource_name, configuration)
      end
      results.join("\n\n")
    end

    def render_resource resource_name, configuration
      md = ["# Group #{resource_name}\n"]

      configuration[:controller].try(:action_configurations).to_a.each do |action|
        case action.action
        when 'index'
          md << "## #{resource_name} Collection [#{action.pathspec}{?#{action.scopes.to_h.keys.join(',')}}]\n"

          md << "- Attributes (array[#{resource_name} Element])\n"
        when 'show'
          md << "## #{resource_name} Element [#{action.pathspec.gsub(/\/\:/, '/{').gsub(/id(\.json|\/)/, 'id}.json')}]\n"

          md << '- Attributes'

          configuration[:serializer].attributes_for_json.each do |column, type|
            md << "  - #{column} (#{type}, required)"
          end
        end
      end

      md.join("\n")
    end

    def required
      method = caller_locations(1, 1)[0].label
      fail ArgumentError, "A required keyword argument was not specified when calling '#{method}'"
    end
  end
end
