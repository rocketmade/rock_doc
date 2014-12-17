module RockDoc::Rendering
  class Markdown
    delegate :t, :t!, to: :rock_doc
    delegate :global_configuration, to: :rock_doc

    attr_accessor :controller_configurations, :serializer_configurations, :rock_doc

    def render doc: required, controller_configurations: required, serializer_configurations: required
      self.rock_doc                  = doc
      self.controller_configurations = controller_configurations
      self.serializer_configurations = serializer_configurations

      toc << global_configuration.toc.map { |t|
        title, anchor, depth, _ = Array(t)
        toc_line title, anchor, (depth || 1)
      }


      md = [title_line(global_configuration.title, 1)]
      blocks = [render_serializers, render_controllers] # run now so toc populates

      md << "\n"
      md += toc
      md << "\n"
      if global_configuration.global_block.present?
        md << global_configuration.global_block
        md << "\n"
      end
      md += blocks
      md.join("\n")
    end

    def supported_json_types
      %w(String Integer Decimal Datetime Text Boolean)
    end

    def toc
      @toc ||= []
    end

    def toc_line title, anchor_name, level
      t = ["  "*(level-1), "- "]
      t << "[" if anchor_name.present?
      t << title
      t += ["](#", anchor_name, ")"] if anchor_name.present?
      t.join('')
    end

    def anchor_line name
      "<a name=\"#{name}\" />"
    end

    def title_line title, depth
      "#"*depth + " " + title
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

    def render_serializers
      toc_depth = 1
      title_depth = 2

      toc << toc_line(t("serializers_toc"), "serializers", toc_depth)
      results = [anchor_line("serializers"), title_line(t("serializers_toc"), title_depth)]

      @serializer_configurations.each do |serializer|
        results << render_serializer(serializer, toc_depth: toc_depth + 1, title_depth: title_depth + 1)
      end
      results.join("\n\n")
    end

    def render_serializer configuration, toc_depth: 2, title_depth: 3
      toc << toc_line(configuration.resource_name, configuration.serializer.name, toc_depth)
      <<JSON
#{anchor_line(configuration.serializer.name)}
#{title_line configuration.resource_name, title_depth}
#{title_line t("json.title"), title_depth + 1}
#{t "json.markdown.start"}
#{configuration.json_representation}
#{t "json.markdown.end"}
#{configuration.notes}
JSON
    end

    def render_controllers
      toc_depth = 1
      title_depth = 2

      toc << toc_line(t("controllers_toc"), "controllers", toc_depth)
      results = [anchor_line("controllers"), title_line(t("controllers_toc"), title_depth)]
      @controller_configurations.each do |controller|
        results << render_controller(controller, toc_depth: toc_depth + 1, title_depth: title_depth + 1)
      end
      results.join("\n\n")
    end

    def render_controller configuration, toc_depth: 2, title_depth: 3
      toc << toc_line(configuration.resource_name, configuration.path, toc_depth)

      md = []
      md << anchor_line(configuration.path)
      md << title_line(configuration.resource_name, title_depth)
      if configuration.json_representation.present?
        md << <<JSON
#{title_line t("json.title"), title_depth + 1}
#{t "json.markdown.start"}
#{configuration.json_representation}
#{t "json.markdown.end"}
JSON
      end

      if configuration.permitted_params.present?
        md << <<PARAMS
#{title_line t("controllers.permitted_parameters"), title_depth + 1}
#{t "json.markdown.start"}
#{configuration.permitted_params}
#{t "json.markdown.end"}

PARAMS
      end

      md << configuration.notes

      configuration.action_configurations.each do |action|
        md << render_action(configuration, action, toc_depth: toc_depth + 1, title_depth: title_depth + 1)
      end


      md.join("\n")
    end

    def render_action controller_configuration, configuration, toc_depth: 3, title_depth: 4

      toc << toc_line(configuration.description, "#{controller_configuration.path}.#{configuration.action}", toc_depth)

      md = []
      md << anchor_line("#{controller_configuration.path}.#{configuration.action}")
      md << title_line(configuration.description, title_depth)
      md << "**#{configuration.verb} #{configuration.pathspec}**"

      if configuration.scopes.present?
        md << "\n"
        md << title_line(t("actions.get_params"), title_depth + 1)
        configuration.scopes.each do |k, v|
          scope = "* `#{k}`"
          scope += ": #{v}" if v.present?
        md << scope
        end
        md << "\n"
      end

      if configuration.notes.present?
        md << ''
        md << title_line(t("actions.notes"), title_depth + 1)
        md << configuration.notes
        md << "\n"
      end

      md.join("\n")
    end

    def required
      method = caller_locations(1,1)[0].label
      raise ArgumentError, "A required keyword argument was not specified when calling '#{method}'"
    end

  end
end
