# coding: utf-8
require 'cli/ui'

module CLI
  module UI
    module Frame
      class UnnestedFrameException < StandardError; end
      class << self
        DEFAULT_FRAME_COLOR = CLI::UI.resolve_color(:cyan)
        DEFAULT_FRAME_STYLE = :box
        VALID_FRAME_SYLES = [:box, :bracket].freeze

        #
        def frame_style
          @frame_style ||= DEFAULT_FRAME_STYLE
        end

        # Set the default frame style.
        #
        # Raises ArgumentError if +frame_style+ is not valid
        #
        # ==== Attributes
        #
        # * +symbol+ - the default frame style to use for frames
        #
        def frame_style=(frame_style)
          validate_frame_style(frame_style)

          @frame_style = frame_style
        end

        # Opens a new frame. Can be nested
        # Can be invoked in two ways: block and blockless
        # * In block form, the frame is closed automatically when the block returns
        # * In blockless form, caller MUST call +Frame.close+ when the frame is logically done
        # * Blockless form is strongly discouraged in cases where block form can be made to work
        #
        # https://user-images.githubusercontent.com/3074765/33799861-cb5dcb5c-dd01-11e7-977e-6fad38cee08c.png
        #
        # The return value of the block determines if the block is a "success" or a "failure"
        #
        # ==== Attributes
        #
        # * +text+ - (required) the text/title to output in the frame
        #
        # ==== Options
        #
        # * +:color+ - The color of the frame. Defaults to +DEFAULT_FRAME_COLOR+
        # * +:failure_text+ - If the block failed, what do we output? Defaults to nil
        # * +:success_text+ - If the block succeeds, what do we output? Defaults to nil
        # * +:timing+ - How long did the frame content take? Invalid for blockless. Defaults to true for the block form
        # * +frame_style+ - The frame style to use for this frame
        #
        # ==== Example
        #
        # ===== Block Form (Assumes +CLI::UI::StdoutRouter.enable+ has been called)
        #
        #   CLI::UI::Frame.open('Open') { puts 'hi' }
        #
        # Output:
        #   ┏━━ Open ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #   ┃ hi
        #   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (0.0s) ━━
        #
        # ===== Blockless Form
        #
        #   CLI::UI::Frame.open('Open')
        #
        # Output:
        #   ┏━━ Open ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #
        #
        def open(
          text,
          color: DEFAULT_FRAME_COLOR,
          failure_text: nil,
          success_text: nil,
          timing:       nil,
          frame_style:  self.frame_style
        )
          validate_frame_style(frame_style)

          color = CLI::UI.resolve_color(color)

          unless block_given?
            if failure_text
              raise ArgumentError, "failure_text is not compatible with blockless invocation"
            elsif success_text
              raise ArgumentError, "success_text is not compatible with blockless invocation"
            elsif !timing.nil?
              raise ArgumentError, "timing is not compatible with blockless invocation"
            end
          end

          t_start = Time.now
          CLI::UI.raw do
            puts edge(text, color: color, first: CLI::UI::Box::Heavy::TL, frame_style: frame_style)
          end
          FrameStack.push(color)

          return unless block_given?

          closed = false
          begin
            success = false
            success = yield
          rescue
            closed = true
            t_diff = elasped(t_start, timing)
            close(failure_text, color: :red, elapsed: t_diff)
            close(failure_text, color: :red, elapsed: t_diff, frame_style: frame_style)
            raise
          else
            success
          ensure
            unless closed
              t_diff = elasped(t_start, timing)
              if success != false
                close(success_text, color: color, elapsed: t_diff, frame_style: frame_style)
              else
                close(failure_text, color: :red, elapsed: t_diff, frame_style: frame_style)
              end
            end
          end
        end

        # Closes a frame
        # Automatically called for a block-form +open+
        #
        # ==== Attributes
        #
        # * +text+ - (required) the text/title to output in the frame
        #
        # ==== Options
        #
        # * +:color+ - The color of the frame. Defaults to +DEFAULT_FRAME_COLOR+
        # * +:elapsed+ - How long did the frame take? Defaults to nil
        # * +frame_style+ - The frame style to use for this frame
        #
        # ==== Example
        #
        #   CLI::UI::Frame.close('Close')
        #
        # Output:
        #   ┗━━ Close ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #
        #
        def close(text, color: DEFAULT_FRAME_COLOR, elapsed: nil, frame_style: self.frame_style)
          validate_frame_style(frame_style)

          color = CLI::UI.resolve_color(color)

          FrameStack.pop
          kwargs = {}
          if elapsed
            kwargs[:right_text] = "(#{elapsed.round(2)}s)"
          end
          CLI::UI.raw do
            puts edge(text, color: color, first: CLI::UI::Box::Heavy::BL, frame_style: frame_style, **kwargs)
          end
        end

        # Adds a divider in a frame
        # Used to separate information within a single frame
        #
        # ==== Attributes
        #
        # * +text+ - (required) the text/title to output in the frame
        #
        # ==== Options
        #
        # * +:color+ - The color of the frame. Defaults to +DEFAULT_FRAME_COLOR+
        # * +frame_style+ - The frame style to use for this frame
        #
        # ==== Example
        #
        #   CLI::UI::Frame.open('Open') { CLI::UI::Frame.divider('Divider') }
        #
        # Output:
        #   ┏━━ Open ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #   ┣━━ Divider ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #
        # ==== Raises
        #
        # MUST be inside an open frame or it raises a +UnnestedFrameException+
        #
        def divider(text, color: nil, frame_style: self.frame_style)
          validate_frame_style(frame_style)

          fs_item = FrameStack.pop
          raise UnnestedFrameException, "no frame nesting to unnest" unless fs_item
          color = CLI::UI.resolve_color(color)
          item  = CLI::UI.resolve_color(fs_item)

          CLI::UI.raw do
            puts edge(text, color: (color || item), first: CLI::UI::Box::Heavy::DIV, frame_style: frame_style)
          end
          FrameStack.push(item)
        end

        # Determines the prefix of a frame entry taking multi-nested frames into account
        #
        # ==== Options
        #
        # * +:color+ - The color of the prefix. Defaults to +Thread.current[:cliui_frame_color_override]+ or nil
        #
        def prefix(color: nil)
          pfx = +''
          items = FrameStack.items
          items[0..-2].each do |item|
            pfx << CLI::UI.resolve_color(item).code << CLI::UI::Box::Heavy::VERT
          end
          if (item = items.last)
            c = Thread.current[:cliui_frame_color_override] || color || item
            pfx << CLI::UI.resolve_color(c).code \
              << CLI::UI::Box::Heavy::VERT << ' ' << CLI::UI::Color::RESET.code
          end
          pfx
        end

        # Override a color for a given thread.
        #
        # ==== Attributes
        #
        # * +color+ - The color to override to
        #
        def with_frame_color_override(color)
          prev = Thread.current[:cliui_frame_color_override]
          Thread.current[:cliui_frame_color_override] = color
          yield
        ensure
          Thread.current[:cliui_frame_color_override] = prev
        end

        # The width of a prefix given the number of Frames in the stack
        #
        def prefix_width
          w = FrameStack.items.size
          w.zero? ? 0 : w + 1
        end

        private

        # If timing is:
        #   Numeric: return it
        #   false: return nil
        #   true or nil: defaults to Time.new
        #   Time: return the difference with start
        def elasped(start, timing)
          return timing if timing.is_a?(Numeric)
          return if timing.is_a?(FalseClass)

          timing = Time.new if timing.is_a?(TrueClass) || timing.nil?
          timing - start
        end

        def edge(text, color: raise, first: raise, right_text: nil, frame_style: self.frame_style)
          color = CLI::UI.resolve_color(color)
          text  = CLI::UI.resolve_text("{{#{color.name}:#{text}}}")

          prefix = +''
          FrameStack.items.each do |item|
            prefix << CLI::UI.resolve_color(item).code << CLI::UI::Box::Heavy::VERT
          end
          prefix << color.code << first << (CLI::UI::Box::Heavy::HORZ * 2)
          text ||= ''
          unless text.empty?
            prefix << ' ' << text << ' '
          end

          termwidth = CLI::UI::Terminal.width if frame_style == :box

          suffix = +''

          if right_text
            case frame_style
            when :box
              suffix << ' ' << right_text << ' '
            when :bracket
              prefix << ' ' << right_text << ' '
            end

          end

          prefix_width = CLI::UI::ANSI.printing_width(prefix)
          prefix_start = 0
          prefix_end   = prefix_start + prefix_width

          # Artificially shrink the calculated width of the terminal to just the length of the prefix
          termwidth = prefix_end if frame_style == :bracket

          suffix_width = CLI::UI::ANSI.printing_width(suffix)
          suffix_end   = termwidth - 2
          suffix_start = suffix_end - suffix_width

          if prefix_end > suffix_start
            suffix = ''
            # if prefix_end > termwidth
            # we *could* truncate it, but let's just let it overflow to the
            # next line and call it poor usage of this API.
          end

          o = +''

          # Shopify's CI system supports terminal emulation, but not some of
          # the fancier features that we normally use to draw frames
          # extra-reliably, so we fall back to a less foolproof strategy. This
          # is probably better in general for cases with impoverished terminal
          # emulators and no active user.
          unless [0, '', nil].include?(ENV['CI'])
            linewidth = [0, termwidth - (prefix_width + suffix_width)].max

            o << color.code << prefix
            o << color.code << (CLI::UI::Box::Heavy::HORZ * linewidth)
            o << color.code << suffix
            o << CLI::UI::Color::RESET.code << "\n"
            return o
          end

          # Jumping around the line can cause some unwanted flashes
          o << CLI::UI::ANSI.hide_cursor

          # reset to column 1 so that things like ^C don't ruin formatting
          o << "\r"

          o << color.code
          o << CLI::UI::Box::Heavy::HORZ * termwidth # draw a full line
          o << print_at_x(prefix_start, prefix)
          o << color.code
          o << print_at_x(suffix_start, suffix)
          o << CLI::UI::Color::RESET.code
          o << CLI::UI::ANSI.show_cursor
          o << "\n"

          o
        end

        def print_at_x(x, str)
          CLI::UI::ANSI.cursor_horizontal_absolute(1 + x) + str
        end

        def validate_frame_style(frame_style)
          unless VALID_FRAME_SYLES.include?(frame_style)
            raise ArgumentError, "Invalid frame style: #{frame_style}.  Expecting one of: :#{VALID_FRAME_SYLES.join(', :')}" # rubocop:disable LineLength
          end
        end

        module FrameStack
          ENVVAR = 'CLI_FRAME_STACK'

          def self.items
            ENV.fetch(ENVVAR, '').split(':').map(&:to_sym)
          end

          def self.push(item)
            curr = items
            curr << item.name
            ENV[ENVVAR] = curr.join(':')
          end

          def self.pop
            curr = items
            ret = curr.pop
            ENV[ENVVAR] = curr.join(':')
            ret.nil? ? nil : ret.to_sym
          end
        end
      end
    end
  end
end
