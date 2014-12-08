module RockDoc::Rendering
  class Markdown
    delegate :t, :t!, to: RockDoc

    attr_accessor :global_config, :controllers, :serializers

    def render global: required, controllers: required, serializers: required
      @global_config = global
      @controllers = controllers
      @serializers = serializers

      toc << global_config.toc.map { |t|
        title, anchor, depth, _ = Array(t)
        toc_line title, anchor, (depth || 1)
      }


      md = [title_line(global_config.title, 1)]
      blocks = [render_serializers, render_controllers] # run now so toc populates

      md << "\n"
      md += toc
      md << "\n"
      if global_config.global_block.present?
        md << global_config.global_block
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

      @serializers.each do |serializer|
        results << render_serializer(serializer, toc_depth: toc_depth + 1, title_depth: title_depth + 1)
      end
      results.join("\n\n")
    end

    def render_serializer config, toc_depth: 2, title_depth: 3
      toc << toc_line(config.resource_name, config.serializer.name, toc_depth)
      <<JSON
#{anchor_line(config.serializer.name)}
#{title_line config.resource_name, title_depth}
#{title_line t("json.title"), title_depth + 1}
#{t "json.markdown.start"}
#{config.json_representation}
#{t "json.markdown.end"}
JSON
    end

    def render_controllers
      toc_depth = 1
      title_depth = 2

      toc << toc_line(t("controllers_toc"), "controllers", toc_depth)
      results = [anchor_line("controllers"), title_line(t("controllers_toc"), title_depth)]
      @controllers.each do |controller|
        results << render_controller(controller, toc_depth: toc_depth + 1, title_depth: title_depth + 1)
      end
      results.join("\n\n")
    end

    def render_controller config, toc_depth: 2, title_depth: 3
      toc << toc_line(config.resource_name, config.controller, toc_depth)

      md = []
      md << anchor_line(config.controller)
      md << title_line(config.resource_name, title_depth)
      if config.json_representation.present?
        md << <<JSON
#{title_line t("json.title"), title_depth + 1}
#{t "json.markdown.start"}
#{config.json_representation}
#{t "json.markdown.end"}
JSON
      end

      if config.permitted_params.present?
        md << <<PARAMS
#{title_line t("controllers.permitted_parameters"), title_depth + 1}
#{t "json.markdown.start"}
#{config.permitted_params}
#{t "json.markdown.end"}

PARAMS
      end

      config.action_configs.each do |action|
        md << render_action(config, action, toc_depth: toc_depth + 1, title_depth: title_depth + 1)
      end


      md.join("\n")
    end

    def render_action controller_config, config, toc_depth: 3, title_depth: 4

      toc << toc_line(config.description, "#{controller_config.controller}.#{config.action}", toc_depth)

      md = []
      md << anchor_line("#{controller_config.controller}.#{config.action}")
      md << title_line(config.description, title_depth)
      md << "**#{config.verb} #{config.pathspec}**"

      if config.scopes.present?
        md << "\n"
        md << title_line(t("actions.get_params"), title_depth + 1)
        config.scopes.each do |k, v|
          scope = "* `#{k}`"
          scope += ": #{v}" if v.present?
        md << scope
        end
        md << "\n"
      end

      if config.notes.present?
        md << ''
        md << title_line(t("actions.notes"), title_depth + 1)
        md << config.notes
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
