# frozen_string_literal: true
module RailsSingleFileComponents
  module TransformPipelines
    class Style
      def initialize(source_io, data_attribute, convert)
        @source_io = source_io
        @parser = Parser.new(@source_io)
        @data_attribute = data_attribute
        @convert = convert
      end

      def transform
        lang = nil
        all_style_contents = @parser.styles.map do |style_section|
          lang ||= style_section.lang
          new_source = apply_preprocessor(lang, style_section.source)
          new_source = apply_data_attribute(lang, new_source) if style_section.scoped?
          new_source
        end.join("\n")
        [all_style_contents, lang]
      end

      private

      def apply_preprocessor(language, source_io)
        case [language, @convert]
          when ['sass', false], ['sass', true]
            source_io
          when ['scss', false]
            source_io
          when ['scss', true]
            Sass::Tree::Visitors::Convert.visit(Sass::Engine.new(source_io, syntax: :scss).to_tree, {}, :sass)
          else
            [::Sass::CSS.new(source_io).render(:sass), 'sass']
        end
      end

      def apply_data_attribute(language, source_io)
        if language == 'sass'
          source_io.split("\n").map do |sass_line|
            case sass_line
              when /[:@+$]/
                sass_line
              when /,/
                sass_line_parts = sass_line.split(",").map { |match| match.gsub(/([[:graph:]]+)/, "\\1[#{@data_attribute}]") }
                if sass_line_parts.size > 1
                  sass_line_parts.join(",")
                else
                  sass_line_parts.first + ","
                end
              when /[[:graph:]]+$/
                sass_line.gsub(/([[:graph:]]+)/, "\\1[#{@data_attribute}]")
              else
                sass_line
            end
          end.join("\n")
        else
          source_io.gsub(/([[:space:]]*[{]|[[:space:]]*,)/, "[#{@data_attribute}]\\1")
        end
      end
    end
  end
end
