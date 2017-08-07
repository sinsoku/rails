require "active_support/time"

module Rails
  module Generators
    class GeneratedAttribute # :nodoc:
      INDEX_OPTIONS = %w(index uniq)
      UNIQ_INDEX_OPTIONS = %w(uniq)

      attr_accessor :name, :type
      attr_reader   :attr_options
      attr_writer   :index_name

      class << self
        def parse(column_definition)
          name, type, has_index = column_definition.split(":")

          # if user provided "name:index" instead of "name:string:index"
          # type should be set blank so GeneratedAttribute's constructor
          # could set it to :string
          has_index, type = type, nil if INDEX_OPTIONS.include?(type)

          type, attr_options = *parse_type_and_options(type)
          type = type.to_sym if type

          if type && reference?(type)
            if UNIQ_INDEX_OPTIONS.include?(has_index)
              attr_options[:index] = { unique: true }
            end
          end

          new(name, type, has_index, attr_options)
        end

        def reference?(type)
          [:references, :belongs_to].include? type
        end

        private

        # parse possible attribute options like :limit for string/text/binary/integer, :precision/:scale for decimals or :polymorphic for references/belongs_to
        # when declaring options curly brackets should be used
        def parse_type_and_options(type_and_options)
          type, *provided_options = type_and_options.to_s.split(/[{},.-]/)
          return type, {} unless provided_options

          options = {}
          case type
          when "string", "text", "binary", "integer"
            limit = provided_options.grep(/\d+/).first
            options[:limit] = limit.to_i if limit
          when "decimal"
            precision, scale = provided_options.grep(/\d+/).first(2)
            options.merge!(precision: precision.to_i, scale: scale.to_i) if precision && scale
          when "references", "belongs_to"
            %i[index foreign_key polymorphic].each do |opt|
              options[opt] = true if provided_options.include?(opt.to_s)
            end
            options[:foreign_key] = !options[:polymorphic]
          end
          options[:null] = provided_options.any? { |opt| %w[null optional].include?(opt) }

          return type, options
        end
      end

      def initialize(name, type = nil, index_type = false, attr_options = {})
        @name           = name
        @type           = type || :string
        @has_index      = INDEX_OPTIONS.include?(index_type)
        @has_uniq_index = UNIQ_INDEX_OPTIONS.include?(index_type)
        @attr_options   = attr_options
      end

      def field_type
        @field_type ||= case type
                        when :integer              then :number_field
                        when :float, :decimal      then :text_field
                        when :time                 then :time_select
                        when :datetime, :timestamp then :datetime_select
                        when :date                 then :date_select
                        when :text                 then :text_area
                        when :boolean              then :check_box
          else
                          :text_field
        end
      end

      def default
        @default ||= case type
                     when :integer                     then 1
                     when :float                       then 1.5
                     when :decimal                     then "9.99"
                     when :datetime, :timestamp, :time then Time.now.to_s(:db)
                     when :date                        then Date.today.to_s(:db)
                     when :string                      then name == "type" ? "" : "MyString"
                     when :text                        then "MyText"
                     when :boolean                     then false
                     when :references, :belongs_to     then nil
          else
                       ""
        end
      end

      def plural_name
        name.sub(/_id$/, "").pluralize
      end

      def singular_name
        name.sub(/_id$/, "").singularize
      end

      def human_name
        name.humanize
      end

      def index_name
        @index_name ||= if polymorphic?
          %w(id type).map { |t| "#{name}_#{t}" }
        else
          column_name
        end
      end

      def column_name
        @column_name ||= reference? ? "#{name}_id" : name
      end

      def foreign_key?
        !!(name =~ /_id$/)
      end

      def reference?
        self.class.reference?(type)
      end

      def polymorphic?
        attr_options[:polymorphic]
      end

      def optional?
        attr_options[:null]
      end

      def has_index?
        @has_index
      end

      def has_uniq_index?
        @has_uniq_index
      end

      def password_digest?
        name == "password" && type == :digest
      end

      def token?
        type == :token
      end

      def inject_options(is_addition: false)
        "".tap do |s|
          attr_options.each { |k, v| s << ", #{k}: #{v.inspect}" }
          s << ", default: #{default.inspect}" if is_addition && !optional?
        end
      end

      def inject_index_options
        has_uniq_index? ? ", unique: true" : ""
      end
    end
  end
end
